# RSB-GEN-001 — 測定エンジンの汎用化（系・応答測定・判定基準の3層分離）

2026-09-28。RSB-003 の本番 run より**前に**行う単位（ユーザー決定 2026-09-28）。
新規 certified VP ではない。**DC を評価しない。登録済み profile で run しない。**

許可範囲: 本 packet、`tools/ReactivationMeasurement/`、`tools/SubstrateRegistry/src/records.jl`
（run 開始レコードへの `criteria` 欄の追加のみ）、`logs/gates/RSB-GEN-001/`。
当初予定した `tools/ReactivationERIEC/` は作らない（§15 の2）。
`src/`・`formal/`・`specs/ledger.toml`・登録済み profile と解析計画は変更しない。

## 1. 目的

測定エンジンを ERIE-C 以外の系・判定基準にも使えるようにする。現在の `measure_case` は、
**汎用的な応答測定**（全停止集合への応答表・喪失集合）と、**ERIE-C 固有の読み出し**
（役割の割り当てに基づく π/ρ/α/σ/ε）を一つの関数で混ぜている。これを分離する。
系の力学はすでに `step(sub, x, silenced)` の1関数に閉じており、そこは型を切り出すだけでよい。

## 2. 3層の構成

| 層 | 内容 | ERIEC 依存 | 置き場 |
|---|---|---|---|
| 1. 系 | `AbstractSystem`、`nunits`、`step` | なし | `tools/ReactivationMeasurement` |
| 2. 応答測定 | `ResponseTable`、`measure_response`、喪失集合 | なし | 同上 |
| 3. 読みと判定 | `AbstractCriterion`、役割割り当て、関係の読み出し、DC・DC2 | 基準による | `tools/ReactivationERIEC`（ERIE-C プラグイン） |

依存は 3 → 2 → 1 の一方向。第1・第2層の最小 Project は `Base.find_package("ERIEC") === nothing`
を検査する。エンジンは判定基準を知らない。

## 3. 介入の種類は「発信停止」に限る（ユーザー決定 2026-09-28）

**本単位の介入は発信停止のみとする。** 停止されたユニットは 0 を送るが、自分の状態は通常どおり
更新される。値の強制・辺単位の切断・確率的介入は扱わない。

理由: 現時点で必要なのは発信停止だけであり、介入を抽象化すると設計が一段重くなる。
**複雑な介入は後から追加してよい。** 追加するときは `AbstractIntervention` を新設し、
既存の発信停止をその一実装に移す。その際は応答表の意味が変わるため、登録済み profile との
互換を改めて確認すること。

この決定は、実装時に `tools/ReactivationMeasurement/src/` の該当箇所のコメントにも記す。

## 4. 停止集合の網羅度を引数にする（両方組み込む。ユーザー決定 2026-09-28）

網羅するか否かの二択ではなく、**停止集合の最大の大きさ `max_silencing_order = k`** を
Protocol の引数にする。

| k | 測る停止集合 | 1 case あたりの分岐数 | 得られる量 |
|---|---|---|---|
| 1 | 空集合と単独停止 | n + 1 | π/ρ/α/σ、つまり **DC の入力はすべて得られる** |
| 2 | 上に加えて2個同時 | 1 + n + n(n−1)/2 | 2重の冗長性まで検出 |
| n | 全停止集合（現行） | 2^n | 包含極小の喪失集合、`collective_only_loss` が完全 |

`loss_sets` と `collective_only_loss` は **k 以下の停止集合の範囲で正確**とし、
出力に `max_silencing_order` を必ず記録する。**k < n のとき、これらを「全体で正確」と
読ませない**ため、記録欄に適用範囲を明示する。

登録済み r2 profile は k = n に相当する現行の網羅方式であり、**本単位ではそのまま維持する。**

## 5. 判定基準の束縛（汎用化で最も危険な点）

汎用化により「一度測り、判定は何度でも」が可能になる。**応答表を見てから通る判定基準を選ぶ
ことができてしまう。**これまで塞いできた「DC が通るまで基体をいじる」ループが、判定基準の層で
再発する。対策を次のとおり定める。

- 登録済み profile の応答表は、**判定基準の集合が run 開始レコードで固定された run の中でしか
  作らない。**
- run 開始レコードの判定基準（`criterion_id` と `criterion_version`）が、登録済み解析計画の
  `primary_criterion` と `recorded_criteria` に一致しなければ `start_run` を拒否する。
- 応答表だけを取り出す公開経路は、`scratch` 基体に対してのみ開く。

## 6. 出どころの強制を型で行う

`evaluate(c::AbstractCriterion, table::ResponseTable, structure::DeclaredStructure)` は
`AbstractSystem` を受け取らない。受け取るのは応答表と、宣言された構造（役割の割り当て、
境界用の隣接）だけ。**判定基準が系の重みを覗き見る経路を型の上で置かない。**
これが解析計画の `PROVENANCE` 撤回条件を構造的に守る。

## 7. 適合試験

**系の適合試験**: 決定性（同じ入力に同じ出力）、発信停止の意味論、`nunits` の範囲、
大域状態を持たないこと。

**判定基準の適合試験**: `required_structure` に宣言したもの以外を読まない、決定性、
結果に `criterion_id` と `criterion_version` を含めること。

## 8. 凍結済み登録との互換（必須）

登録済み r2 profile は `case_record_format = "rsb-case-record-v1"` を凍結している。
**ERIE-C プラグインは汎用化後も `rsb-case-record-v1` を1バイトも変えずに出力する。**
現行エンジンと汎用化後のパイプラインが fixture 上で**同一の case 記録**を出すことを
golden test で確認する。一致しなければ先へ進まず、取り下げと再登録を検討する。

## 9. 手順

1. `measure_case` を `measure_response`（汎用）と ERIE-C の読み出しに分ける。
2. golden test で現行出力との完全一致を確認する。**一致しなければ止める。**
3. `AbstractSystem` を切り出し、閾値網をその一実装にする。系の適合試験を置く。
4. `max_silencing_order` を導入する。k = n の出力が現行と一致することを再確認する。
5. `AbstractCriterion` を定め、判定基準を run 開始レコードへ束縛する。
6. ERIE-C プラグインを作る（読み出し。DC adapter と DC2 は RSB-003）。
7. **2つ目の系で汎用性を実証する**（基本セルオートマトン等）。適合試験だけで差し込めること。

## 10. 反証条件

| ID | 内容 | 期待 |
|---|---|---|
| `FALSIFICATION-GEN-GOLDEN` | 汎用化後の出力が現行と1バイトでも違う | 手順2で停止 |
| `FALSIFICATION-GEN-CRITERION-MISMATCH` | run 開始レコードの判定基準が解析計画と不一致 | `start_run` が拒否 |
| `FALSIFICATION-GEN-RAW-TABLE` | 登録済み profile の応答表を run 外で取得 | 公開経路が存在しない |
| `FALSIFICATION-GEN-SYSTEM-PEEK` | 判定基準が系の重みを参照 | 型の上で不可能 |
| `FALSIFICATION-GEN-ORDER-SCOPE` | k < n の喪失集合を全体で正確と記録 | 記録欄の適用範囲で拒否 |
| `FALSIFICATION-GEN-NONDETERMINISTIC` | 非決定的な `step` | 系の適合試験が拒否 |
| `FALSIFICATION-GEN-ERIEC-LEAK` | 第1・第2層が ERIEC を読み込む | 最小 Project の検査が拒否 |

## 11. ゲート

G1・G2 は `formal/` に及ばないため不要。G3 は隔離スイートと全体 `Pkg.test()`。
G4 は certificate を登録しないため不要。**台帳の status は動かさない。**

## 12. 未決（実装後も残るもの）

- 大きな系で用いる k の既定値。**k = 1 と k = n の双方で測れる中規模の系（n = 10〜12）で、
  両者の判定がどれだけ食い違うかを先に測ってから決める**ことを推奨する（理由は付記）。
- k < n の系を本番に使う場合は、初期配置も全列挙できないため抽出が必要になり、
  **抽出計画を別の解析計画として事前登録する必要がある。**

## 15. 実装で確定・修正した点（2026-09-28）

実装の過程で、上の設計から次のとおり変えた。いずれも理由を付けて記録する。

1. **判定基準が読むのは応答表ではなく case 記録にした。** §6 は `evaluate(c, table, structure)` と
   書いたが、登録済み profile が凍結しているのは case 記録の形式であり、DC の入力 π/ρ/α/σ も
   そこにある。応答表から読ませると DC 側で読み出しを再実装することになり、二つの実装が
   ずれうる。case 記録にも系のパラメータは含まれないので、§6 の出どころの強制は保たれる。
2. **`rsb-case-record-v1` の読み出しはエンジン側に置いた。** ERIEC を必要とせず、登録済み profile の
   `[output]` が形式を固定しているので、記録形式を選ぶ層（`AbstractRecordFormat`）としてエンジンに
   入れた。ERIEC に依存するのは DC と DC2 だけで、それは RSB-003 のプラグインになる。
   したがって本単位では `tools/ReactivationERIEC/` を作らない。
3. **記録形式を2つにした。** 登録済みの `rsb-case-record-v1`（全停止集合を要求し、それ未満の表を
   拒否する）と、系を問わない `rsb-response-record-v1`（任意の k、喪失欄の名前を `..._up_to_order`
   とし全体についての主張と読ませない）。登録済み profile の schema は前者しか許さない。
4. **k の適用範囲を正確に述べられるようになった。** 大きさ k 以下の停止集合の族は下に閉じているので、
   k 以下で見つかった包含極小の喪失集合は**全体でも極小**である。見えないのは k より大きい極小集合だけ。
   テストで、k 未満の表の結果が全停止集合の結果のうち大きさ k 以下の部分と一致することを確かめている。
5. **判定基準の束縛は run 開始レコードに記録する。** `SubstrateRegistry` の run 開始レコードに
   `criteria` 欄を足し、`record_schema_version` を 2 に上げた。値は `id|version|定義モジュール` で、
   試験用の代役がどのモジュールで定義されたかが記録に残る。
6. **`RAW-TABLE` は security boundary としては守れない。** `measure_response` は公開 API であり、
   誰でも凍結 profile から系を組み立てて応答表を得られる。Julia に access control は無い（RSB-001 §2）。
   守っているのは「サポートされる run の経路では、判定基準を固定してからでないと応答表を作らない」
   ことと、既存の `NO-CANDIDATE-RUN` 検査（凍結 profile の測定記録がゲートログにも試験にも無いこと）
   である。§10 の期待「公開経路が存在しない」はこの意味に読み替える。
7. 上限を定数にした。状態のビット幅から `MAX_UNITS = 62`、分岐数の上限 `MAX_BRANCHES = 2^22`。

## 16. 実行したゲート（実出力）

| 対象 | 結果 | ログ |
|---|---|---|
| 測定エンジン隔離スイート | 70537/70537 PASS（独立 fixture 1391/1391 を含む） | `logs/gates/RSB-GEN-001/isolated-suite-20260928.log` |
| うち GEN-GOLDEN | 1697/1697。848 case で Dict と TOML バイト列が現行と一致 | 同上 |
| SubstrateRegistry 隔離スイート | 119/119 PASS | `logs/gates/RSB-GEN-001/substrate-registry-suite-20260928.log` |
| 変異テスト5件 | 5件とも検出（落ちたテスト 6・1024・2・1・1件） | `logs/gates/RSB-GEN-001/mutation-20260928.log` |
| 全体 `Pkg.test()` | PASS。末尾 `Testing ERIEC tests passed`、失敗・エラー 0 件。隔離スイート2本もサブプロセス経由で通過 | `logs/gates/RSB-GEN-001/pkg-test-20260928.log` |

G1・G2 は `formal/` に及ばないため対象外、G4 は certificate を登録しないため対象外。
台帳の status は動かしていない。**登録済み profile での測定は一度も行っていない。**
