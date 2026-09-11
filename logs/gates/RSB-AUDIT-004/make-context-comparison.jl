using TOML
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ClaimAudit.jl"))

circuit = ModelAudit.AuditCircuit(units=(:e1,:m1,:e2,:m2), motors=(:m1,:m2), inputs=(:e1,:e2),
    edges=((1,2,1),(2,1,1),(3,4,1),(4,3,1)), thresholds=(1,1,1,1),
    initial=(true,true,false,false), P=6,H=6,L=4,R=4)
supports = ((:e1,:m1),(:e2,:m2))
claims = ClaimAudit.AuditClaim[]
for include_initial in (true,false)
    report = ModelAudit.symmetry_audit_report(ModelAudit.audit_candidate_supports(circuit,supports; include_initial))
    context = ModelAudit.AuditContext(question_id="functional-support", question="固定された支持候補が存在するか",
        definition_version="automorphism-support-v1", definition="指定contextの全自己同型で固定される候補",
        assumptions=("候補は二つのe-m対のみ", "重み・閾値・入出力役割を保存する"),
        observation=report["context"], subject=ModelAudit._audit_digest(ModelAudit.circuit_dict(circuit)))
    id = include_initial ? "with-initial" : "dynamics-only"
    claim = ClaimAudit.AuditClaim(claim_id=id, context=context, proposition="固定候補が存在する",
        verdict=isempty(report["fixed_candidates"]) ? :denied : :affirmed,
        reason="明示したcontextで自己同型と固定候補を全列挙した。選択の一意性は主張しない。",
        evidence=("logs/gates/RSB-AUDIT-003/symmetry-examples.toml", "computed-report-sha256:" * ModelAudit._audit_digest(report)))
    push!(claims,claim)
    open(io -> TOML.print(io,ClaimAudit.claim_record(claim); sorted=true),joinpath(@__DIR__,id*".toml"),"w")
end
comparison = ClaimAudit.compare_claim_records(claims...)
@assert comparison["classification"] == "different_context" && comparison["opposite_verdicts"]
open(io -> TOML.print(io,comparison; sorted=true),joinpath(@__DIR__,"comparison.toml"),"w")

# Keep the experiential question separate; the functional result does not discharge it.
original = ModelAudit.AuditContext(question_id="original-experience", question="なぜこの視点から経験しているのか",
    definition_version="original-question-v1", definition="元の問い。機能的支持候補の存在に置換しない。",
    observation="not operationalized", subject="original first-person question")
history = ModelAudit.append_audit_event((),original,:open; reason="元の問いを先に保持")
history = ModelAudit.append_audit_event(history,claims[1].context,:open; reason="限定された機能的な問いを別に登録")
history = ModelAudit.append_audit_event(history,claims[1].context,:conditional;
    reason="初期状態を含むcontextでは固定候補が存在する。存在の一意性や経験所有者については答えていない。",
    evidence=("with-initial.toml", "comparison.toml"))
@assert ModelAudit.audit_history_summary(history).unresolved_count == 1
write(joinpath(@__DIR__,"residual-history.toml"),ModelAudit.audit_history_toml(history))
println("PASS opposite claims have different contexts; original experiential question remains open")
