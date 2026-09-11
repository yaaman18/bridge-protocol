using Test
root = normpath(joinpath(@__DIR__,"..","..",".."))
# Load the sibling tools first, then the original suite, to exercise shared module identity.
for file in ("test_claim_audit.jl","test_background_audit.jl","test_model_audit.jl",
             "test_model_audit_circuits.jl","test_model_audit_symmetry.jl")
    include(joinpath(root,"test",file))
end
@testset "audit sibling modules share the context type" begin
    context = ModelAudit.AuditContext(question_id="integration",question="同じ型を共有するか",
        definition_version="v1",definition="same context type",observation="module identity",subject="audit tools")
    claim = ClaimAudit.AuditClaim(claim_id="integration",context=context,proposition="context type is shared",
        verdict=:affirmed,reason="constructor accepted the context",evidence=("integration test",))
    @test claim.context === context
    @test BackgroundAudit.ModelAudit === ModelAudit
    @test ClaimAudit.ModelAudit === ModelAudit
end
