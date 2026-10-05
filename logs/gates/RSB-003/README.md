# RSB-003 DC・DC2 判定基準プラグインのゲート 2026-10-04

packet: `specs/packets/RSB-003.md`。パッケージ: `tools/ReactivationERIEC`。凍結（tree OID）と解析計画 v2 への記入はしていない。
登録済み profile は測定していない。

## 実行したもの

| ファイル | 内容 |
|---|---|
| `plugin-tests.log` | `julia --project=tools/ReactivationERIEC -e 'using Pkg; Pkg.test()'`。452 件すべて通過 |
| `mutations.jl`, `mutations.out` | DC の変異4件。意味を変える変異（境界を入辺で読む、ε を空として読む）は独立実装との照合が検出。α・σ の制限を外す変異は、記録形式がすでに制限しているので等価変異（検出不能が正しい） |
| `test_*.log` | DC2 コードの移動後の、リポジトリ側の試験（DC2 監査6本、countermodel、implication matrix、解析計画照合、model audit、試験計画）。すべて通過 |
| `reactivation-measurement-tests.log` | 測定エンジン自身の試験 70,537 件、通過（エンジンは無変更） |

## プラグインの試験の中身（`tools/ReactivationERIEC/test/runtests.jl`）

1. 判定基準の適合性と、値・診断のキー集合が解析計画 v2 草案の `criterion_binding` と完全一致（DC2 の欄は本作業で記入）。
2. DC が、ERIEC を使わないビットマスクの独立実装と、ランダムな基体 240 個の全初期状態で一致。ε が空でない case を 200 以上含む。
3. 同じ回路を有限モデル監査（ModelAudit）とエンジンで測り、κ・DC の4条件・DC2 の主要欄が一致（4ユニット全列挙 32,768、6ユニット系列の先頭 4,000）。
4. 解析計画 v2 草案で `PENDING-RSB-003` だった反証行: ALL-OFF、DC2-IMPLIES-DC（ランダム）、DC2-GRAPH-BOUNDARY（κ が全ユニットの fixture。
   ランダムな基体では入力が持続しないため一度も生じなかった）、REDUNDANCY（冗長な支えの fixture が ambiguous に分類され、冗長を外すと分類されない）。
5. scratch 登録で `start_run` を本物の2判定基準で通し、全 case が判定され、判定結果が形式検査を通る。

## コードの移動

DC2 の判定コード（`check_dc2` と補助関数）を `tools/model_audit/DC2.jl` から `tools/ReactivationERIEC/src/dc2_core.jl` に移した。
監査側はそのファイルを `include` するので、監査したコードと束縛されるコードは同じファイル。9/30 の変異スクリプトの読み込み先も更新した。
