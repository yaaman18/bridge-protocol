using Test
using JSON3
using ERIEC

include(joinpath(@__DIR__, "..", "tools", "verify", "cert_scope_validation.jl"))
using .CertScopeValidation

@testset "certified envelope claim scope" begin
    fixture_dir = joinpath(@__DIR__, "fixtures", "cert_scope")
    negative_cases = [
        "missing.toml" => "CERT_SCOPE_MISSING",
        "permanent.toml" => "CERT_SCOPE_FORBIDDEN",
        "final.toml" => "CERT_SCOPE_FORBIDDEN",
        "unconditional_cross_context.toml" => "CERT_SCOPE_FORBIDDEN",
        "unknown.toml" => "CERT_SCOPE_UNKNOWN",
    ]
    for (fixture, expected_code) in negative_cases
        violations = validate_cert_scope(joinpath(fixture_dir, fixture))
        @test [violation.code for violation in violations] == [expected_code]
    end

    artifact = CertifiedArtifact(2, "scope-test-boundary", CertifiedContract[])
    artifact_check = CertifiedArtifactCheck(
        artifact,
        String[],
        CertifiedContract[],
        CertifiedContract[],
        CertifiedContract[],
    )

    envelope = certified_artifact_envelope((kind=:scope_test,), artifact_check)
    @test envelope.claim_scope == :context_local
    @test isempty(cert_scope_violation_codes(envelope))
    @test isempty(validate_cert_scope(envelope))

    for forbidden in (:permanent, :final, :unconditional_cross_context)
        @test_throws ArgumentError certified_artifact_envelope(
            (kind=:scope_test,),
            artifact_check;
            claim_scope=forbidden,
        )
    end
    @test_throws ArgumentError certified_artifact_envelope(
        (kind=:scope_test,),
        artifact_check;
        claim_scope=:unknown,
    )

    mktempdir() do temporary_directory
        valid_path = joinpath(temporary_directory, "valid.json")
        open(valid_path, "w") do io
            JSON3.write(io, envelope)
        end
        valid_audit = certified_json_artifact_audit(valid_path)
        @test valid_audit.ok
        @test valid_audit.claim_scope_ok
        @test isempty(valid_audit.claim_scope_violations)

        forbidden_path = joinpath(temporary_directory, "permanent.json")
        open(forbidden_path, "w") do io
            JSON3.write(io, merge(envelope, (claim_scope=:permanent,)))
        end
        forbidden_audit = certified_json_artifact_audit(forbidden_path)
        @test !forbidden_audit.ok
        @test !forbidden_audit.claim_scope_ok
        @test forbidden_audit.claim_scope_violations == ["CERT_SCOPE_FORBIDDEN"]
    end
end
