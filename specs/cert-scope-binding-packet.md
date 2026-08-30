# 証書射程の意味束縛（相A2）— Stage 2 実装パケット（2026-08-30）

状態: **ユーザー承認済み**（2026-08-30、相A2 の実施を指示）。codex レビュー → 実装。
前提: 相A1 完了（`specs/cert-scope-hygiene-packet.md`、`logs/gates/cert-scope/G3-20260830-112231.log`）。

## この相が establish すること / しないこと（先に書く）

相A1 で過剰主張をして差し戻された。同じ誤りを繰り返さないため、境界を先に固定する。

**establish する**:
- 証書の射程が、呼び出し側の自由申告ではなく、**catalog 側の宣言に拘束される**こと。
- **強い射程を名乗るには Lean 宣言を名指しし、その名前が catalog に実在することが必須**であること。
  実在しなければ名乗れない。
  **限定（codex 指摘 2026-08-30）**: 検証されるのは「**名目的な参照が catalog の宣言に解決する**」
  ことだけである。名指された宣言が当該契約の保存性を実際に establish しているか、という
  **意味的な関連は検証しない**。これを閉じるには、宣言と契約の対応を機械検証する規則が別途要る。
- 現 catalog には跨ファイバー保存定理が無い（codex 監査で確認済み）ため、
  **結果としていかなる契約も強い射程を名乗れない状態**になること。

**establish しない**:
- 保証文面（prose）が実際に永続性を述べていないこと。**文面は機械解析しない。**
  `scope_kind` を `context_local` と宣言しつつ保証文面に永続的な内容を書く、という不一致は
  検出できない。
- したがって `FM-CALLER-PROOF-BOOL` は A2 でも**完全には解消しない**。
  改善されるのは、宣言の場所が「実行時に任意の呼び出し側」から
  「**低頻度で審査される 164 行の catalog**」へ移り、かつ強い値には**証拠の実在が必要**になる点。
  自己申告の余地は残る。これが現時点の天井であり、閉じるには prose の形式化か人手の審査が要る。

## 設計

### 契約ごとの `scope_kind`（registry に置く）

```
scope_kind ∈ {
  context_local,                 # 許可（既定）
  cross_context_conditional,     # 許可。ただし preservation_decl 必須
  disputed,                      # 未解決の記録。証書の根拠にはできない
  unconditional_cross_context,   # 禁止（表現可能・棄却）
  permanent,                     # 禁止
  final,                         # 禁止
}
```

### `disputed` — 停止の代わりに可視ギャップとして記録する（v1 からの変更）

ある契約が `context_local` では正しくないと判明した場合、**バッチを停止しない**。
`scope_kind = "disputed"` を付けて先へ進み、`disputed` の一覧と件数を報告する。

理由は三つある。

第一に、1 件の契約が残る 158 件を止めるのは費用が見合わない。
第二に、**停止は誤ラベルを誘発する**。バッチが止まると停止を解消する圧力が生じ、いちばん簡単な
解消法は `context_local` と書いて進むことである。停止条件が、防ごうとした誤ラベルの原因になる。
第三に、これは可視ギャップ原則そのものである。圏論的主張はあるが裏付けが無いものを黙って消さず、
`status < certified` として可視化する、という既存の運用と同じ形にする。

**`disputed` は抜け道にならない。** `disputed` な契約を根拠とする envelope は棄却されるため、
`disputed` を付けることは主張を弱めるのではなく**証書を発行できなくする**。
逃げるために付ける動機が生じない向きになっている。

- registry は 164 契約すべてに `scope_kind` を持つ。欠落は違反。
- **`cross_context_conditional` を名乗る契約は `preservation_decl` を持ち、その宣言が
  catalog（`formal/ERIEC/CertifiedArtifact.lean`）に実在しなければならない。**
  実在しなければ違反。これが「証拠なしに強い射程を名乗れない」の実体である。
- 禁止 3 値は A1 と同じ理由で **enum に含めた上で棄却する**。表現できなければ拒否が空虚になる。
- 初期値は全 164 件 `context_local`。現 catalog に跨ファイバー保存定理が無いため、
  `cross_context_conditional` を名乗れる契約は現時点で存在しない。

### envelope 側との整合

envelope の `claim_scope`（相A1 で導入済み）は、**その envelope が認証する契約群の
`scope_kind` を超えてはならない**。順序は `context_local < cross_context_conditional` とし、
禁止値は順序に入れない（常に棄却）。

### 既存 `scope` との分離（厳守）

`checker-semantic-manifest` の既存 `scope` は**有限 checker 入力範囲**であり、天候 scope ではない。
**overloading 禁止。** `scope_kind` は別欄として追加する。

## 実装対象

1. **`specs/cert-scope-registry.toml`（新規ファイル）** — 契約 ID を鍵に `scope_kind` を持つ
   独立した registry。全 164 契約分のエントリを作り、初期値は `context_local`。
   `preservation_decl` は付与しない（該当なしのため）。

   **manifest に列を足さない理由（codex 指摘 2026-08-30 を受けた変更）**:
   `src/model_evaluation.jl:667-687` の `_model_evaluation_require_head_bytes` が
   semantic manifest の作業木 bytes と HEAD blob の完全一致を要求し、
   同 `:718-726` で `specs/checker-semantic-manifest.toml` に適用されている。
   `test/test_model_evaluation.jl:386` 以降が通常 pass 経路でこれを実行するため、
   **manifest に列を足した未コミット状態では既存 G3 が必ず落ちる**。
   commit 禁止・変更可能ファイル限定・既存テスト合否不変の三条件と両立しない。

   別ファイルに分けることは回避策であると同時に、**設計上も正しい**。
   manifest の `scope` は有限 checker 入力範囲について述べており、`scope_kind` は
   認証射程について述べている。軸が違うものを同じ表に置かない、というのは
   overloading 禁止の指摘と同じ原則である。

   採らなかった代案: (A) G3 前のローカル checkpoint commit — 未ゲートの変更を
   コミットすることになり順序が逆。(B) `model_evaluation` の HEAD binding とテストの変更 —
   既存の不変条件を自分の都合で弱めることになる。**不採用。**

1b. **registry と manifest の整合テスト** — registry の契約 ID 集合が manifest の 164 件と
   一致すること。過不足を違反符号で検出する。
2. `src/certification.jl` — `scope_kind` の判定 core（A1 の `cert_scope_violation_codes` と
   同じ場所・同じ形）。`preservation_decl` の catalog 実在検査。
   envelope の `claim_scope` と契約群の `scope_kind` の整合検査。
3. `tools/verify/cert_scope_validation.jl` — core を呼ぶ wrapper を拡張。**独自判定を持たない。**
4. `test/test_cert_scope.jl` — 正例と負例 fixture を追加（`test/fixtures/cert_scope/`）。
5. `test/test_checker_semantic_manifest.jl` — registry との ID 集合一致検査を追加。
   **manifest 自体の行は変更しない**（HEAD binding のため）。
6. `test/parallel_test_plan.jl` — 変更不要の見込み。必要なら更新可。

**変更可能ファイルは上記 6 件。** `formal/ERIEC/CertifiedArtifact.lean` は**読み取りのみ**
（`preservation_decl` の実在検査のため）。書き換えは禁止。

### 安定違反符号（固定名）

- `SCOPE_KIND_MISSING` — 契約に `scope_kind` が無い
- `SCOPE_REGISTRY_ID_MISMATCH` — registry の契約 ID 集合が manifest の 164 件と一致しない
- `SCOPE_KIND_FORBIDDEN` — `unconditional_cross_context` / `permanent` / `final`
- `SCOPE_KIND_UNKNOWN` — enum に無い値
- `PRESERVATION_DECL_MISSING` — `cross_context_conditional` なのに `preservation_decl` が無い
- `PRESERVATION_DECL_NOT_IN_CATALOG` — `preservation_decl` が catalog に実在しない
- `CLAIM_SCOPE_EXCEEDS_CONTRACT` — envelope の `claim_scope` が契約群の `scope_kind` を超える
- `CONTRACT_SCOPE_DISPUTED` — envelope が `disputed` な契約を根拠にしている

## 反証条件（**ゲート項目として実行し、条件ごとに識別できる出力をログへ残すこと**）

前回の申し送りを適用する。ログだけを読む者が、どの条件が走ったか判定できる形にすること。
各条件の実行時に `FALSIFICATION-A2-<n>: PASS/FAIL` の形式で 1 行出力する。

1. 負例 fixture ごとに、**期待した違反符号だけ**が返ること。
2. `scope_kind = permanent`（および `final` / `unconditional_cross_context`）を持つ契約が
   **必ず棄却される**こと。
3. `scope_kind` を省いた契約が棄却されること（省略が抜け道にならない）。
4. **`cross_context_conditional` を名乗り、実在しない `preservation_decl` を指す契約が
   棄却されること。** これが本パケットの中核であり、通れば目的を達していない。
5. `cross_context_conditional` を名乗り `preservation_decl` を省いた契約が棄却されること。
6. envelope の `claim_scope` が契約群の `scope_kind` を超える組み合わせが棄却されること。
7. 現行 164 契約が違反ゼロで通ること（`disputed` が付いた契約があればそれも含めて
   manifest 検査は通る。`disputed` は manifest の違反ではない）。回帰なし。
8. **`disputed` な契約を根拠とする envelope が棄却されること**（`CONTRACT_SCOPE_DISPUTED`）。
   `disputed` が抜け道にならないことの確認。
9. registry の契約 ID 集合から 1 件抜いた／余分に足した状態が
   `SCOPE_REGISTRY_ID_MISMATCH` で棄却されること。registry と manifest の乖離が
   黙って通らないことの確認。

## 禁止変更

- `formal/ERIEC/CertifiedArtifact.lean` の書き換え（読み取りのみ）。
- `checker-semantic-manifest` の既存 `scope` / `assumptions` / `guarantee` の意味変更・流用。
- 既存 `relation` 値の変更、および `relation` と `scope_kind` の同一視。両者は別の軸である。
- `context_id` / `weather_id` / `T′` の導入（別相）。
- 保証文面（prose）の機械解析を試みること。**本相の範囲外であり、できないと明記した。**
- 許容誤差・seed・fixture 値・`phenomenal_claim`。
- 既存テストの合否を変えること。
- 判定の二重実装（tools 側に独自ロジックを置くこと）。
- commit / push。

## ゲート

- **G3**: `tools/quiet-test.sh` 経由で `Pkg.test()`。既存全テスト不変
  （claim ledger 861/861、packet review 19/19、cert scope 18/18 から増加して全通過）、
  registry と manifest の ID 集合一致検査が 164 件で通ること。ログ `logs/gates/cert-scope/G3-A2-<timestamp>.log`。
- **反証条件 1〜9 を G3 の一部として実行し、`FALSIFICATION-A2-<n>` 形式の識別可能な出力を
  ログに含めること。**

## 停止条件

- 既存テストの合否が 1 件でも変わったら、回避策を入れず停止して報告。
- 上記 6 件以外の変更が必要になったら停止。
- `CertifiedArtifact.lean` を書き換えざるを得ないと判明したら停止。
- **（v1 から変更）164 契約のいずれかが `context_local` では正しくない場合は、停止せず
  `disputed` を付けて先へ進む。** バッチ終了時に `disputed` の契約 ID 一覧と件数を報告すること。
  その一覧が、ユーザーの理論的判断を要する項目になる。
  ただし `disputed` が 164 件中の過半に達した場合は停止して報告すること
  （schema そのものが現実に合っていない可能性があるため）。
- `relation` と `scope_kind` を結ぶ必要が生じたら停止（軸が違うため、結ぶなら別途設計が要る）。
