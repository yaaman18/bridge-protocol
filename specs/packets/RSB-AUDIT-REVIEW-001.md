# RSB-AUDIT-REVIEW-001 — 12d7be9 レビュー修正

2026-09-13、ユーザー依頼: 修正と検証の後、Claude Codeへ再レビューを依頼する。
新規certified VPではなく、ledgerのstatusを動かさない。

変更可能:
- test/parallel_test_plan.jl、test/parallel_test_runner.jl、test/test_test_plan.jl
- tools/model_audit/{Records,Witnesses,Search}.jl、tools/CountermodelAudit.jl
- tools/ConstraintOverlayAudit.jl、bin/eriec-model-audit.jl
- test/test_model_audit.jl、test/test_model_audit_circuits.jl、test/test_constraint_overlay_audit.jl
- 本packet、specs/packets/RSB-AUDIT-{001,002,009,013}.md
- logs/gates/RSB-AUDIT-REVIEW-001/、logs/reviews/rsb-audit-review-fixes-20260913*

依存理由: runner起動時の登録網羅性検査により、登録されないテスト自身では検出できない
欠落を防ぐ。CLI変更は履歴診断を実際の利用者にも届けるため。
直接依存: 既存ModelAudit/check_DC、AssumptionSuiteAudit、Julia標準ライブラリ。
既存tool API名、正式export、formal/src/catalog、数値条件、対象層、markerは保持。

修正契約:
- test_*.jlは全件登録する。重複・存在しない登録・登録漏れはworker起動前に拒否。
- contextの全体固定は採用しない。既存テストとdesign §12は同IDへの追加前提による
  conditional遷移を許す。question ID/原文の不変性と既存status集計を保持し、
  同IDの直前eventからの文脈変更を、sequence・差分・変更前後のcontext付きで公開する。
  unresolved_countは最新申告statusの集計であり、元の文脈での解決数ではない。
- 制約の結論がtargetのvaluationに無い場合はunknown_conclusionsに記録する。
  constraint_check_complete=falseを併記し、既知のconflictと両立させる。
  classificationは既存の有限探索/既知矛盾の分類を保持し、新分類には置換しない。
- checker間の一致は独立な意味検証ではない。入力検査を弱めず、一致assertionを保持。
  テストに小有限台の独立な述語計算を追加する。探索再測定では共通trace/lossとmodelも照合。
- nondegenerateはκ≠∅ ∧ κ≠C ∧ ε≠∅のみ。active_boundary等の効力は別診断。

検証: 修正前に回帰テストの失敗を記録、修正後に対象G3、全体Pkg.test()。
formal/src/接続は無変更なので既存G1/G2/G4 baselineを利用し、全体テスト中の接続検査も確認。
各成功・失敗ログを分離し、差分と対応表をClaude Codeへ送る。commit/pushは含めない。
