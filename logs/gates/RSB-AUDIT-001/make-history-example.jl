using TOML
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))

context = ModelAudit.AuditContext(
    question_id="symmetry-example", question="交換対称な二候補から不変な一候補を選べるか",
    definition_version="finite-action-v1", definition="与えた全置換で固定される候補",
    assumptions=("候補はleftとrightのみ", "交換(2,1)を許された作用とする"),
    observation="ModelAudit.invariant_choices", subject="抽象二候補モデル")
history = ModelAudit.append_audit_event((), context, :open; reason="元の問いを保存")
fixed = ModelAudit.invariant_choices((:left, :right), [(2, 1)])
@assert isempty(fixed)
history = ModelAudit.append_audit_event(history, context, :conditional;
    reason="指定した交換作用には固定候補がない。物理系の対称性や経験所有者については未判定。",
    evidence=("model-witnesses-20260910.toml#symmetry", "test/test_model_audit.jl"))
write(joinpath(@__DIR__, "history-example.toml"), ModelAudit.audit_history_toml(history))
receipt = ModelAudit.audit_receipt(history)
open(joinpath(@__DIR__, "history-example-receipt.toml"), "w") do io
    TOML.print(io, Dict("count" => receipt.count, "head" => receipt.head); sorted=true)
end
println("PASS example history created; receipt is illustrative, not an authenticated external anchor")
