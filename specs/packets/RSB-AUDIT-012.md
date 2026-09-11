# RSB-AUDIT-012 — 背景別の全条件・単独脱落suite

2026-09-11、継続実装の第十二単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、
tools/AssumptionSuiteAudit.jl、bin/eriec-assumption-suite-audit.jl、
test/test_assumption_suite_audit.jl、test/parallel_test_plan.jl、logs/gates/RSB-AUDIT-012/。
直接依存: CountermodelAudit.finite_model_catalog。
固定tool API: assumption_suite_report。

DCの述語順を hSelf/hSMC/hAct/hBound に固定し、全trueと各一条件だけfalseの5パターンを
exact targetとして照合する。次の3つの有限contextを別suiteとする。

- P3・二入力二モータ・adjunction=true・nondegenerate=true
- P6・一入力一モータ・adjunction=true・nondegenerate=true
- P6・一入力二モータ・adjunction=false・nondegenerate=true

背景条件と4述語のすべてが既知のモデルだけを対象にし、未知をfalseにしない。
該当モデルがあればwitness_found、なければnot_found_in_finite_catalogとする。
後者を一般的不可能性や仮定の冗長性に昇格しない。P3とP6のsuiteを混ぜて不足を補わない。
全条件例は退化条件nondegenerate=trueも同時に要求する。

このsuiteが示すのは保存回路を再測定した有限観測モデルのパターンだけである。
M1〜M4全体、現象性、所有者、分解の内在的一意性は認証しない。

対象G3: 5 exact targets、P3とM2脱落P6の完全suite、一入力contextの未発見維持、
非退化条件、未知値除外、context分離、CLI。
既存G1/G2/G4接続・対象層・formal/・src/・ledger・catalog・candidateは変更しない。
