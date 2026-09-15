# RSB-AUDIT-REVIEW-002 — LOW-A/B 修正とセルフレビュー

2026-09-13、ユーザー直接依頼。修正・対象テスト・セルフレビューを行い、Claude Codeには送信しない。
先行REVIEW-001の未コミット変更とレビューsnapshotを保存したまま、今回の差分を分離する。

対象: ConstraintOverlayAudit.constraint_overlay_report、DC参照テスト。
変更可能: tools/ConstraintOverlayAudit.jl、test/test_constraint_overlay_audit.jl、
test/test_model_audit.jl、specs/packets/RSB-AUDIT-013.md、本packet、
logs/gates/RSB-AUDIT-REVIEW-002/、logs/reviews/rsb-audit-review-002-self-review-20260913*。
直接依存: 既存AssumptionSuiteAudit、ModelAudit.check_dc_pattern、Julia Test/TOML。

固定契約:
- 最上位incomplete_check_countはconstraint_check_complete=falseのtarget行数。
  未指定の結論キーの数ではなく、適用済み制約に関する既存の行診断を集計する。
  conflict_count/classificationとは別軸とし、未知と既知の矛盾が併存できる。
- CLIは既存のreport全体をTOML出力する経路を利用し、出力を対象テストで確認する。
- DCの参照式は保持。完全グラフと鎖e→m→cの各4096通りを検証する。
  鎖でhBoundがκの非空真部分集合性と異なるケースを必須とする。
- 公開API名・export・既存分類・formal/src/ledger/catalog/Project/Manifest・数値条件・markerは保持。

検証: 集計欠落と既存完全グラフの被覆不足を示す修正前テストの失敗ログを保存し、
修正後に対象2ファイルのG3を実行する。境界をneighbors無視へ変えた一時コピーで新テストの拒否を確認。
実行計画や正式API接続は無変更なので全体Pkg.test/G1/G4は再実行しない。
先行REVIEW-001の全体成功を今回の差分の全体再検証と呼ばない。ledger statusの更新なし。
セルフレビュー結果・今回のみのdiff/hashをローカルに保存する。commit/push/agent送信は行わない。
