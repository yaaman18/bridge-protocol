using ERIEC
using TOML
using Test

@testset "existing DC dependency anchor (no new certification)" begin
    check = ERIEC.verify_lean_certified_artifact()
    @test ERIEC.certified_artifact_ok(check)
    detail = only(filter(c -> c.id == "dc.system", check.artifact.contracts))
    @test detail.lean_full_name == "ERIEC.DC"
    @test detail.julia_checker == :check_DC
    registry = TOML.parsefile("specs/cert-scope-registry.toml")
    scope = only(filter(c -> c["id"] == "dc.system", registry["contract"]))
    @test scope["scope_kind"] == "context_local"
    manifest = TOML.parsefile("specs/checker-semantic-manifest.toml")
    semantic = only(filter(c -> c["id"] == "dc.system", manifest["contract"]))
    @test semantic["checker_relation"] == "witness_validator"
    @test semantic["checker"] == "check_DC" && semantic["lean_decl"] == "ERIEC.DC"
    # Diagnostic dependency extraction only; no tool/model certificate is emitted.
    payload = (kind=:DCResult, lean_contracts=["dc.system"], julia_checkers=["check_DC"])
    graph = ERIEC.certificate_dependency_graph((; payload,
        certificate=ERIEC.certification_summary(check), trust=ERIEC.certificate_trust_profile(payload)))
    @test (from=:DCResult, to="dc.system", relation=:lean_contract) in graph.edges
    @test (from="dc.system", to="ERIEC.DC", relation=:lean_dependency) in graph.edges
    println("scope=context_local phenomenal_claim=not_certified new_certification=false")
end
