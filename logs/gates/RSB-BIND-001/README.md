# RSB-BIND-001 判定基準の束縛と解析計画 schema v2 のゲート 2026-10-08

packet: `specs/packets/RSB-BIND-001.md`（RSB-PLAN-002 §2(2) のうち §3・§4.2・§8・§9）。
scratch 登録だけで試験した。登録済み profile では run していない。登録・再登録もしていない。

| ファイル | 内容 |
|---|---|
| `registry-tests.log` | SubstrateRegistry の既存試験 119 件、通過（v1 の経路は無変更で通る） |
| `engine-tests.log` | ReactivationMeasurement の試験。既存 70,538 件（試験ファイルが1つ増えたため、登録済み profile 名を含まないことの検査が1件増えた）と RSB-BIND-001 の 21 件、すべて通過 |
| `plugin-tests.log` | ReactivationERIEC の試験 457 件、通過（v1 の scratch run を含む） |

## RSB-BIND-001 の試験（`tools/ReactivationMeasurement/test/binding_v2.jl`）

試験専用の判定基準パッケージ `ScratchCriteria` を runner checkout の中に置き、そこから読み込む。

| 検査 | 結果 |
|---|---|
| 登録したパッケージを登録した場所から読み込む | run が完了 |
| STAND-IN（試験モジュールで定義した同名の判定基準） | `start_run` が拒否、出力なし |
| FOREIGN-LOAD（同名・同 tree の別の場所 `tools/OtherCopy` を登録し、実際は `tools/ScratchCriteria` から読み込む） | 拒否、出力なし |
| criterion_version が登録値と違う | 拒否 |
| RESULT-KEYS（診断の欄を1つ足す） | 最初の case で run が失敗し、完了 manifest は作られない |
| TREE-DRIFT（登録後にパッケージを変え、runner をその commit に進める） | 検証は通る（束縛範囲は profile_commit〜registration_commit）が、`start_run` が拒否 |
| TREE-DRIFT（profile_commit と registration_commit のあいだで変える） | 検証が `BINDING_TREE_CHANGED` で拒否 |
| 登録した OID が profile_commit の tree と違う | 検証が `BINDING_TREE_MISMATCH` で拒否 |
| schema v2 の拒否（v1 として読む、binding が recorded_criteria と一致しない、`expected_components` の型、未知のセクション） | すべて拒否 |

解析計画 v2 草案は、`PENDING-RSB-003` の tree OID を仮の 40 桁で埋めれば schema v2 を通ることを確認した
（埋めなければ `package_tree_oid` の 2 件だけで拒否される）。登録済みの解析計画 v1 は v1 schema で引き続き通る。

## 範囲外（次の作業単位）

RSB-PLAN-002 §6 の再実行の方針（試行番号、1回目の出力の封印、重なる case の一致検査、3回目の拒否）と、
§3.5 の `src/` tree OID の run 開始レコードへの記録。

## 追記: §3.5 依存ツリーの記録（2026-10-08）

`criterion_binding` に `dependency_paths`（束縛しないが run 開始時に tree OID を記録するディレクトリ）を加え、
run 開始レコード v3 に `dependency_tree_oids`（`criterion_id|path|tree_oid`、存在しなければ `absent`）を加えた。
RSB-PLAN-002 §3.5 は ERIE-C の `src/` を名指ししていたが、エンジンを ERIE-C に依存させないため、パスは解析計画で宣言する形に一般化した。
解析計画 v2 草案では dc・dc2 ともに `dependency_paths = ["src"]`。
試験: `engine-tests-dependency-trees.log`（束縛と再実行の試験 39 件、既存 70,538 件、通過）、
`registry-tests-dependency-trees.log`（119 件、通過）。

