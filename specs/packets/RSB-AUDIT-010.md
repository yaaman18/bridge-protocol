# RSB-AUDIT-010 — 有限反例台帳と含意照会

2026-09-11、継続実装の第十単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、tools/CountermodelAudit.jl、
bin/eriec-countermodel-audit.jl、test/test_countermodel_audit.jl、test/parallel_test_plan.jl、
logs/gates/RSB-AUDIT-010/。
直接依存: ModelAudit、BackgroundAudit、ClosureAuditの再測定済みモデル。
固定tool API: CountermodelAudit.finite_model_catalog、CountermodelQuery、query_countermodels、
countermodel_query_report、parse_countermodel_query。

各モデルにcontext ID、回路digest、観測できたBoolean述語だけを付す。未知述語をfalseにしない。
照会はcontext IDs、premises、Boolean conclusionを必須にし、同じcontext内のモデルだけを比較する。
前提を満たし結論を反転するモデルがあれば、指定された有限encodingにおける反例として返す。
見つからなければnot_found_in_finite_catalogであり、含意の証明や一般的不可能性へ昇格しない。
異なる時間窓・入出力数を無指定で混ぜず、contextを空にした照会を拒否する。

許可述語: adjunction、hSelf/hSMC/hAct/hBound、all_dc、nondegenerate、active_boundary、
kappa_subset_future、kappa_subset_nu、kappa_equals_nu、candidate_selection_obstructed。
最後の述語は対称合併fixtureで候補クラスまで検査した場合だけ既知。他モデルではunknown。
値は再測定と既存checkerから算出し、台帳入力から関係や判定を個体側へ書き戻さない。

対象G3: 背景付き分離、DC⇒K=νΦの反例、最大支持⇒成分選択の反例、
未知値の除外、context混同拒否、未発見を証明扱いしないこと、厳格TOML、CLI。
既存G1/G2/G4接続・対象層・src/・ledger・catalog・candidateは変更しない。
