# RSB-AUDIT-013 — 有限未発見とLean実験制約の重ね合わせ

2026-09-12、継続実装の第十三単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、
tools/ConstraintOverlayAudit.jl、bin/eriec-constraint-overlay-audit.jl、
test/test_constraint_overlay_audit.jl、test/parallel_test_plan.jl、logs/gates/RSB-AUDIT-013/。
直接依存: AssumptionSuiteAudit、formal-experiments/OneInputAdjunction.lean（変更なし）。
固定tool API: constraint_overlay_report。

一入力、M2随伴、K/epsilon非空、hSelfという明示仮定からhSMCとhActが従うLean実験命題を、
背景別suiteへ重ねる。Lean sourceのSHA-256を固定して、statementが変更された場合は停止する。
これはdefault targetやcertificate catalogに登録された定理ではないため、分類名は
`incompatible_with_checked_experimental_statement` とし、certified/provedへ昇格しない。

有限台帳で未発見かつ実験statementの前提を満たし結論を反転するtargetは上記分類にする。
statementと衝突するtargetに将来witness_foundが入った場合は`conflict_requires_review`とする。
実験statementで排除されない未発見は`not_found_in_finite_catalog`のままにする。
異なるcontextやadjunction=falseのsuiteへstatementを適用しない。

適用制約の結論がtargetのvaluationで未指定なら、unknown_conclusionsへ制約ID・結論キー・
Lean宣言を記録し、constraint_check_complete=falseとする。既知の矛盾は同時に保持する。
classificationは既存の有限探索結果/既知矛盾の分類であり、未知結論の適合判定ではない。
constraint_check_completeは適用済み制約の結論に限る診断で、前提不明の非適用制約の検査済みを意味しない。

対象G3: source digest、15 targets、該当2件、単なる未発見2件、背景外非適用、
人工的な証人衝突のreview分類、CLI。個別Lean再検査を別ログに保存する。
既存G1/G2/G4接続・対象層・formal/・src/・ledger・catalog・candidateは変更しない。
