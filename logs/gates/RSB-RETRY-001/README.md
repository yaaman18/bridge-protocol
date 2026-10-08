# RSB-RETRY-001 再実行の方針のゲート 2026-10-08

packet: `specs/packets/RSB-RETRY-001.md`（RSB-PLAN-002 §6）。scratch 登録だけで試験した。登録済み profile では run していない。

| ファイル | 内容 |
|---|---|
| `engine-tests.log` | ReactivationMeasurement の試験。既存 70,538 件、RSB-BIND-001 と RSB-RETRY-001 を合わせて 37 件、すべて通過 |
| `registry-tests.log` | SubstrateRegistry の既存試験 119 件、通過 |
| `plugin-tests.log` | ReactivationERIEC の試験 459 件、通過（新しい反証行 UNMASKED を含む） |
| `test_analysis_plan_expectations.log` | 解析計画 v2 草案の照合 1441 + 2、通過 |
| `mutation-overlap.jl` / `.out` | 重なる case の照合を外した変異: 2 件の試験が失敗（検出） |
| `mutation-third.jl` / `.out` | 試行の上限と再試行の条件を外した変異: 4 件の試験が失敗（検出） |

最初の変異試験は、置き換えた関数の型注釈が元と違い、元のメソッドが使われ続けたため、変異が効いていなかった。
シグネチャを揃えて再実行したものが上の結果である。

## 確かめたこと（`tools/ReactivationMeasurement/test/binding_v2.jl` の `retry_checks`）

| 検査 | 結果 |
|---|---|
| 1回目が case 5 で止まり、2回目が完了する | `complete`。2回目の run 開始レコードは version 3、`attempt = 2`、1回目の run_id と封印の SHA-256 を持つ |
| THIRD-ATTEMPT（同じ runs root で3回目） | 拒否、出力なし |
| 1回目が完了済みなのに2回目 | 拒否 |
| run_id の試行番号がエンジンの判定と違う | 拒否 |
| RETRY-MISMATCH（1回目の重なる case 記録を1バイト変えてから2回目） | `retracted`（`retry_overlap_mismatch`） |
| 封印した後に1回目のファイルが変わる | `previous_attempt_changed` |

## 記録の形式の変更

- run 開始レコード: v2 の解析計画の run は `record_schema_version = 3`（`attempt`、`previous_attempt_run_id`、
  `previous_attempt_seal_sha256`）。v1 の run は version 2 のまま。
- 完了 manifest: `status` に `retracted`、不一致の符号に `retry_overlap_mismatch` と `previous_attempt_changed` を追加。

## 解析計画 v2 草案への追加

RSB-PLAN-002 §10 の反証行のうち手続きの 6 行（STAND-IN、TREE-DRIFT、FOREIGN-LOAD、RESULT-KEYS、RETRY-MISMATCH、
THIRD-ATTEMPT）と、値の行 UNMASKED（hBound が偽なら冗長性では隠れないので fail）を加えた。草案の反証行は 17 行。
