# ループ・オーケストレーション設計書 v1 — chat→圏論→Lean→Julia の programmable 化

**担当**: claude（設計）→ codex（driver/watcher 実装）
**対象**: 開発ループ全体（②圏論化〜⑤Julia実装）の機械化
**方針決定**: 完全自動（ゲート失敗時のみ停止・人間通知） ＋ 既存 agmsg + fswatch を拡張
**前提資産**: `watch-specs.sh`, agmsg claude↔codex 分業, `test/test_formal_julia_contract.jl`, `formal/ERIEC/CertifiedArtifact.lean`→TSV→`src/certification.jl`, `certificate_dependency_graph`

> 本書は「コードを書かずに仕様だけ決める」段階の成果物。データスキーマ（TOML）と状態機械・トリガ図のみを定義し、driver/watcher の実装は codex に委ねる。

---

## §0. 設計原理

ループが programmable かどうかは「**各ステージ間に機械チェック可能な契約があるか**」だけで決まる。本ループで本質的に fuzzy なのは **②chat→圏論の1ステップだけ**で、③④⑤はすべて `lake build` / `Pkg.test()` / certificate catalog という硬いゲートに落ちる。

決定的な enabling change は、**散文の `[検証点 N]` を機械可読な「検証点台帳」に昇格**させ、それを single source of truth として圏論spec・Lean定理・Julia checker・test に貫通させること。台帳の各エントリは状態機械上を進み、driver はゲートが通った分だけ状態を進め、落ちたら担当へ差し戻す。

不変条件（programmable の根拠）:
- **冪等性**: source（議論ログ・spec・formal・src）に変化が無ければ driver 再実行で状態は変わらない。
- **純粋性**: 各ゲートは `(台帳, リポジトリ状態)` の純関数。chat 履歴に依存しない。
- **可視ギャップ**: 圏論的主張で Lean 証明が無いものは `status < certified` として可視化され、黙って消えない。

---

## §1. 検証点台帳（claim ledger）— `specs/ledger.toml`

唯一の真実源。各検証点が1エントリ。`category/tensor_categorical_v5.md` の `[検証点 N]` から起票され、4ステージを貫く識別子を持つ。

```toml
schema_version = 1

[[vp]]
id          = "VP-ADJ-002"                                  # 安定ID。全ステージで不変
source      = "category/tensor_categorical_v5.md#§2"        # 由来（②圏論spec の位置）
claim_ja    = "α_w★ ⊣ σ_w★（感覚運動随伴 = ガロア接続）"
lean_decl   = "ERIEC.Adj.galoisConn_induced"                # G1 が存在＋typecheck を照合
lean_file   = "formal/ERIEC/Adjunction.lean"
julia_api   = "check_galois_conn"                           # G2 が export/対応を照合
julia_file  = "src/adjunction.jl"
contract_id = "adjunction.system"                           # G4 が certificate catalog と照合
owner       = "codex"                                       # ゲート失敗時の差し戻し先
depends_on  = []                                            # 先行 VP-id（順序づけ・トポロジカル実行）
status      = "certified"                                   # §2 の状態
pinned      = false                                         # true なら driver は自動遷移しない（人間凍結）
```

`status` 値域: `proposed | formalized | bound | implemented | certified | failed`
`owner` 値域: `claude`（設計・圏論・台帳）/ `codex`（Lean・Julia実装）
（既存の claude=設計／codex=実装 分業を踏襲。Julia 実装も当面 codex。VP 単位で上書き可。）

`failed` のエントリは `fail_gate`（"G1".."G4"）と `fail_log`（最新ゲート出力への相対パス）を追加で持つ。

---

## §2. 状態機械とゲート

```
proposed ──G1──▶ formalized ──G2──▶ bound ──G3──▶ implemented ──G4──▶ certified
   │               │                  │              │
   └──G1 fail──┐   └──G2 fail──┐      └──G3 fail──┐  └──G4 fail──┐
               ▼               ▼                  ▼              ▼
            failed(差し戻し: owner へ agmsg 通知。当該エントリは停止)
```

| ゲート | 遷移 | 検査内容 | 既存コマンド | 失敗時の差し戻し |
|---|---|---|---|---|
| **G1 証明** | proposed→formalized | `lake build` 成功 ∧ `lean_decl` が `lean_file` に存在し typecheck 済み | `lake build` | codex（Lean実装） |
| **G2 接続** | formalized→bound | `lean_decl`↔`julia_api` 対応が contract test を通過 | `julia ... test_formal_julia_contract.jl` | codex |
| **G3 実装** | bound→implemented | 当該 `julia_api` を含むテスト群が通過 | `Pkg.test()`（対象 testset） | codex |
| **G4 認証** | implemented→certified | `contract_id` が certificate catalog に登録され、`certificate_dependency_graph` に `payload_kind→contract→Lean decl` の edge が存在 | `verify_lean_certified_artifact` / 依存グラフ抽出 | codex |

- ゲートは台帳順序を `depends_on` でトポロジカルソートしてから評価（先行 VP が certified 未満なら後続はスキップし `blocked` 表示、status は据え置き）。
- 各ゲートは純関数。`pinned=true` のエントリは driver が触らない（人間凍結・実験用）。

---

## §3. ②chat→圏論の自動化（完全自動方針）

完全自動方針のため、②も LLM（claude ロール）が起票する。新しい議論ログが現れたら spec-synthesizer を起動する。

入力: `docs/*discussion*.md`, `docs/ChatGPT.md`, `docs/inline_chat_prompts.md` の更新
出力（claude ロールが生成）:
1. `category/三層構造の圏論的定式化_v5_1.md` への圏論節追記（`[検証点 N]` マーカー付き）
2. `specs/<phase>-spec.md`（既存 `phase1-adjunction-spec.md` 体裁。Lean 署名案・定理 statement 案・使用補題まで）
3. `specs/ledger.toml` への `status="proposed"` エントリ追記（`lean_decl` / `julia_api` / `contract_id` は**命名規約に基づく予約名**として埋める）

品質リスク（完全自動の代償）: 圏論の方向性を LLM に委ねるため、起票直後のエントリは `pinned` で人間が凍結レビューできる退避口を残す。誤起票は台帳から削除すれば G1 にすら到達しない。

---

## §4. 既存 fswatch + agmsg の拡張

現状: `watch-specs.sh` が `specs/` の `.md/.lean` 変更を検知 → codex へ agmsg 通知。これを以下のトリガグラフに拡張する。

```
[T0] docs/*discussion*.md, ChatGPT.md, inline_chat_prompts.md  変更
       └─(fswatch)→ agmsg send: claude
            "新議論。検証点を起票し圏論節・spec・ledger を更新せよ"
            └→ claude: §3 の生成物を書き出し（→ T1/T2 を誘発）

[T1] specs/ledger.toml  変更（新 proposed / status 更新）
       └─(fswatch)→ driver 実行（§5）

[T2] specs/*.md, specs/*.lean, formal/**, src/**  変更
       └─(fswatch)→ driver 実行（影響 VP のゲート再評価。冪等）
```

watcher 追加分（`.specs-bin/` に新スクリプト or `watch-specs.sh` 拡張）:
- `WATCH_DIR` を `docs/`（議論ログのみ grep）と `formal/`・`src/` に拡張
- ファイル種別ごとに送信先を出し分け（議論→claude、ledger/formal/src→driver 起動）
- 既存の `specs/` → codex 通知は維持

agmsg 役割（既存 team `erie`、`send.sh` 流用）:
- driver → `owner`：ゲート失敗時に `[G{n} fail] VP-xxx: <要約> log=<path>` を送信
- claude ⇄ codex：従来どおり設計⇄実装のやり取り

---

## §5. driver（状態機械オーケストレータ）

単一エントリポイント（例 `bin/eriec-loop-driver.jl` または `.specs-bin/driver.sh`）。fswatch から起動され、以下を実行:

1. `specs/ledger.toml` を読む
2. `depends_on` でトポロジカルソート
3. 各 `pinned=false` エントリについて、現 status の**次のゲート**を1段だけ試行
   - pass → status を1段進めて台帳に書き戻し
   - fail → `status="failed"`, `fail_gate`, `fail_log` を記録し `owner` へ agmsg 通知（当該エントリ停止）
   - 先行依存が未 certified → スキップ（status 据え置き）
4. サマリを stdout と `specs/ledger-status.md`（人間用ダッシュボード）へ出力

要件:
- **冪等**: source 不変なら再実行で台帳不変
- **単段遷移**: 1回の起動で各エントリ最大1ゲートのみ進める（ループの観測可能性を担保）
- **ログ保全**: 各ゲート出力を `logs/gates/VP-xxx/G{n}-<timestamp>.log` に保存（timestamp は driver 起動時に外部から付与）

---

## §6. 台帳整合テスト（検証の背骨）

driver とは別に、CI 兼用の整合テスト `test/test_ledger_consistency.jl` を追加し、台帳がリポジトリ実体と乖離しないことを保証:

- 全 `[検証点 N]`（圏論spec内）が台帳に対応 `id` を持つ（orphan claim 検出）
- 全 `status=certified` の `lean_decl` が `formal/` に存在
- 全 `status=certified` の `julia_api` が Julia から export 済み
- 全 `status=certified` の `contract_id` が certificate catalog に登録済み
- `depends_on` が DAG（循環なし）

これにより「圏論的主張はあるが Lean 証明が無い」状態は必ず `status<certified` として可視化され、ループの取りこぼしが構造的に防がれる。

---

## §7. 実装順（codex 向け）

1. `specs/ledger.toml` スキーマ確定と、既存 `[検証点]`（少なくとも v5 §2 の随伴）からの初期エントリ手起こし（5〜10件）
2. `test/test_ledger_consistency.jl`（§6）— 台帳と実体の整合を先に固める
3. driver（§5）の G1〜G4 評価ロジック — 既存コマンドを叩くだけ。新規証明ロジックは不要
4. fswatch 拡張（§4 T1/T2）と driver 起動配線
5. spec-synthesizer（§3）と T0 配線 — ②自動化。ここが唯一の LLM 生成ステップ
6. `specs/ledger-status.md` ダッシュボード生成

> 1〜4 で③④⑤の自動ループが回り始める（②は当面手起こしでも動く）。5 で②まで含めた完全自動になる。
