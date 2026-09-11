# RSB-AUDIT-008 — 観測支持と最大不動点の区別

2026-09-10、継続実装の第八単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、tools/ClosureAudit.jl、
bin/eriec-closure-audit.jl、test/test_closure_audit.jl、test/parallel_test_plan.jl、logs/gates/RSB-AUDIT-008/。
対象宣言（無変更）: ERIEC.Closure.Phi、ERIEC.Closure.NuPhi。
直接依存: 既存ERIEC.nu_phi/check_nu_phi_fixedpoint/check_final_coalgebra、ModelAuditの有限台検査。
固定tool API: ClosureAudit.check_observed_closure、closure_audit_report。

完全な有限C上でνΦを求め、固定点性・最大固定点性・全postfixed集合の被覆を既存checkerで照合する。
K⊆Φ(K)、K⊆νΦ、K=νΦを別々に表示する。結果をκ、元のtrace、選択器、個体側へ書き戻さない。
対象のCは12以下。既存のmax_iter既定値と数値条件は変えない。
これはM1全体、身体、世界、経験の認証ではなく、指定された有限関係の固定点についての検査。
ViableSystem.viableとDCを同一視しない。

対象G3: 既存checkerとの全有限集合照合、Kが真部分集合となる測定例、KがνΦ外に出るhSelf不成立例、
反復の収束、入力台不正の拒否、CLIの区別表示。既存G1/G2/G4接続に変更なし。
