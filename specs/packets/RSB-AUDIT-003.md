# RSB-AUDIT-003 — 回路の対称性と観測上の必要条件

2026-09-10、継続実装の第三単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、tools/ModelAudit.jl、
tools/model_audit/Symmetry.jl、bin/eriec-model-audit.jl、test/test_model_audit_symmetry.jl、
test/parallel_test_plan.jl、formal-experiments/{MeasuredPersistence,EquivariantChoice}.lean、
logs/gates/RSB-AUDIT-003/。

直接依存: ModelAudit.AuditCircuit、ERIEC.Closure、Leanの基礎等式論理。
固定tool API: circuit_automorphisms、audit_candidate_supports、symmetry_audit_report。
探索は8ユニット以下で全置換を列挙（上限は計算量の制約であり理論上の仮定ではない）。
役割M/E、各重み、閾値を保存する置換を検出する。include_initial=trueは初期配置も保存し、
falseは力学だけを比較する別contextとして表示する。時刻P/H/L/Rを置換で変更しない。
候補はC内の非空proper支持集合。候補クラスが作用で閉じていなければ判定を拒否する。
固定候補0件はこのcontextでの不変選択を妨げる。1件は対称性との整合だけであり、
内在的分解の十分性、身体、経験所有者、現象性を認証しない。2件以上は未選択として残す。

実験Leanの固定宣言:
ERIEC.ModelAuditExperiment.phi_subset_of_pi_subset
ERIEC.ModelAuditExperiment.measured_self_requires_future_persistence
ERIEC.ModelAuditExperiment.no_self_of_past_outside_future
ERIEC.ModelAuditExperiment.no_equivariant_selector_at_fixed_object
背景と結論を明示した補題だけを置く。既存対象層へ新公理・対象を足さず、本体からimportしない。
禁止変更: formal/本体、src/、catalog、ledger、candidate、既存数値条件、marker。

検証: G1 baselineのquiet-buildと実験ファイルの個別Lean検査を両方記録。
既存G2/G4 bindingはRSB-AUDIT-001から無変更。対象G3は対称回路・初期状態による破れ・
候補クラス非閉性の拒否・各置換に対する全状態/全介入の可換性・CLIのcontext表示。
全体G3はRSB-AUDIT-002と併せて実行。新規certificateと台帳状態変更はない。
