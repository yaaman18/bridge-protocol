# RSB-AUDIT-005 — M2を背景に加えたときの条件分離

2026-09-10、継続実装の第五単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、tools/BackgroundAudit.jl、
bin/eriec-background-audit.jl、test/test_background_audit.jl、test/parallel_test_plan.jl、logs/gates/RSB-AUDIT-005/。
対象宣言（無変更）: ERIEC.Adj.ERIESystem、ERIEC.DC。
直接依存: ModelAuditの有限encoding検査、既存ERIEC.check_galois_conn/alpha_star/sigma_star/powerset。
固定tool API: BackgroundAudit.check_adjunction_background、relative_abstract_models、background_audit_report。

M2をDCへ隠れて追加せず、背景の真偽とDCの全真偽値を別に表示する。
有限M/Eの全N⊆M/X⊆Eについてα*(N)⊆X ↔ N⊆σ*(X)を検査し、
不成立なら最初の反例N/Xと両側の真偽値を保存する。M/Eの合計は10以下に制限する。
関係のconverse性だけから随伴を推定しない。既存checkerとの結果一致も照合する。
抽象関係ではM2背景を保った全条件/各条件分離の5例を別に構成し、
測定由来の5例と旧6ユニット測定例にはM2の成否を付記する。
この結果を身体・世界・M1〜M4全体の充足や現象性へ一般化しない。

禁止変更: formal/、src/、既存catalog/ledger/candidate、数値条件、対象層公理、marker。
対象G3: 全有限集合による既存checker照合、最小の反例提示、M2背景を保った条件分離、
測定由来モデルへの背景判定、CLIの区別表示。既存G1/G2/G4 bindingは無変更。

追加範囲: formal-experiments/OneInputAdjunction.lean。
依存理由: Eが一要素、M2随伴、K/ε非空という背景ではhSelfからhSMC/hActが導かれるため、
探索の「未発見」と背景からの「分離不能」を区別する補題を検査する。
固定宣言: ERIEC.ModelAuditExperiment.sigma_full_of_one_input_gc、
ERIEC.ModelAuditExperiment.one_input_gc_self_implies_smc_and_act。
直接import: ERIEC.Adjunction、ERIEC.Closure、ERIEC.Hinge。
既存rigidity_of_gcを使用し、対象層への追加公理・本体importは行わない。
G1 baselineと個別Lean検査を追加で記録する。
