# RSB-AUDIT-011 — context別の有限含意行列

2026-09-11、継続実装の第十一単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、
tools/ImplicationMatrixAudit.jl、bin/eriec-implication-matrix-audit.jl、
test/test_implication_matrix_audit.jl、test/parallel_test_plan.jl、logs/gates/RSB-AUDIT-011/。
直接依存: CountermodelAudit.finite_model_catalog。
固定tool API: implication_matrix_report、find_implication。

同じ有限context内で、観測述語 `A=true` から別の観測述語 `B=true` への全単項含意を
機械的に照合する。各cellは、両述語が既知のモデル、前提を満たすモデル、結論を反転する
有限反例、未知モデルを分けて数える。分類は次の4種に限定する。

- counterexample_found
- no_counterexample_in_finite_catalog
- premise_uninstantiated_in_finite_catalog
- predicate_unobserved_in_context

後三者を含意の証明に昇格しない。すべてのcellで implication_proved=false、
general_impossibility=not_established、phenomenal_claim=not_certified とする。
context間の行を合成せず、異なるP/H/L/R・入出力数を同じ母集団として数えない。
この行列は単一の正の前提だけを扱う。複数前提またはfalse値への照会はRSB-AUDIT-010の
明示的なCountermodelQueryを使う。述語論理上の推移閉包や論理的同値を推測しない。

対象G3: 行数、context分離、4分類、既知の有限反例、未発見の非証明、未知値の除外、CLI。
既存G1/G2/G4接続・対象層・formal/・src/・ledger・catalog・candidateは変更しない。
