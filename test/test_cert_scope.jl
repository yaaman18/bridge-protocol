using Test
using JSON3
using TOML
using ERIEC

include(joinpath(@__DIR__, "..", "tools", "verify", "cert_scope_validation.jl"))
using .CertScopeValidation

function record_a2_falsification(condition::Integer, ok::Bool)
    println("FALSIFICATION-A2-$condition: $(ok ? "PASS" : "FAIL")")
    @test ok
end

function rejects_with_code(f, code::AbstractString)
    try
        f()
        false
    catch err
        err isa ArgumentError && occursin(code, sprint(showerror, err))
    end
end

@testset "certified envelope claim scope" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    fixture_dir = joinpath(@__DIR__, "fixtures", "cert_scope")
    registry_path = joinpath(project_root, "specs", "cert-scope-registry.toml")
    manifest_path = joinpath(
        project_root,
        "specs",
        "checker-semantic-manifest.toml",
    )
    registry = TOML.parsefile(registry_path)
    manifest = TOML.parsefile(manifest_path)
    catalog_artifact = lean_certified_artifact(; project_root=project_root)
    catalog_declarations = Set(
        contract.lean_full_name for contract in catalog_artifact.contracts
    )

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

    binding_negative_cases = [
        "scope_kind_missing.toml" => "SCOPE_KIND_MISSING",
        "scope_kind_permanent.toml" => "SCOPE_KIND_FORBIDDEN",
        "scope_kind_final.toml" => "SCOPE_KIND_FORBIDDEN",
        "scope_kind_unconditional_cross_context.toml" => "SCOPE_KIND_FORBIDDEN",
        "scope_kind_unknown.toml" => "SCOPE_KIND_UNKNOWN",
        "preservation_decl_missing.toml" => "PRESERVATION_DECL_MISSING",
        "preservation_decl_not_in_catalog.toml" =>
            "PRESERVATION_DECL_NOT_IN_CATALOG",
    ]
    binding_fixture_results = Dict{String,Vector{String}}()
    for (fixture, expected_code) in binding_negative_cases
        violations = validate_contract_scope(
            joinpath(fixture_dir, fixture);
            catalog_declarations=catalog_declarations,
            project_root=project_root,
        )
        codes = [violation.code for violation in violations]
        binding_fixture_results[fixture] = codes
        @test codes == [expected_code]
    end
    record_a2_falsification(1, all(
        binding_fixture_results[fixture] == [expected]
        for (fixture, expected) in binding_negative_cases
    ))
    record_a2_falsification(2, all(
        binding_fixture_results[fixture] == ["SCOPE_KIND_FORBIDDEN"]
        for fixture in (
            "scope_kind_permanent.toml",
            "scope_kind_final.toml",
            "scope_kind_unconditional_cross_context.toml",
        )
    ))
    record_a2_falsification(
        3,
        binding_fixture_results["scope_kind_missing.toml"] ==
            ["SCOPE_KIND_MISSING"],
    )
    record_a2_falsification(
        4,
        binding_fixture_results["preservation_decl_not_in_catalog.toml"] ==
            ["PRESERVATION_DECL_NOT_IN_CATALOG"],
    )
    record_a2_falsification(
        5,
        binding_fixture_results["preservation_decl_missing.toml"] ==
            ["PRESERVATION_DECL_MISSING"],
    )

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

    catalog_check = CertifiedArtifactCheck(
        catalog_artifact,
        String[],
        CertifiedContract[],
        CertifiedContract[],
        CertifiedContract[],
    )
    local_payload = (
        kind=:scope_binding_test,
        lean_contracts=["adjunction.system"],
        julia_checkers=Symbol[],
        numeric_assumptions=NamedTuple(),
    )
    local_envelope = certified_artifact_envelope(local_payload, catalog_check)
    @test local_envelope.claim_scope == :context_local
    claim_exceeds_rejected = rejects_with_code(
        () -> certified_artifact_envelope(
            local_payload,
            catalog_check;
            claim_scope=:cross_context_conditional,
        ),
        "CLAIM_SCOPE_EXCEEDS_CONTRACT",
    )
    record_a2_falsification(6, claim_exceeds_rejected)

    registry_codes = ERIEC.cert_scope_registry_violation_codes(
        registry,
        manifest;
        catalog_declarations=catalog_declarations,
        project_root=project_root,
    )
    registry_ids = [String(row["id"]) for row in registry["contract"]]
    manifest_ids = [String(row["id"]) for row in manifest["contract"]]
    current_registry_ok = isempty(registry_codes) &&
        length(registry_ids) == length(manifest_ids) == 164 &&
        Set(registry_ids) == Set(manifest_ids)
    record_a2_falsification(7, current_registry_ok)

    disputed_registry = deepcopy(registry)
    disputed_registry["contract"][1]["scope_kind"] = "disputed"
    disputed_probe = (payload=local_payload, claim_scope=:context_local)
    disputed_codes = ERIEC.cert_scope_binding_violation_codes(
        disputed_probe,
        disputed_registry,
        manifest;
        catalog_declarations=catalog_declarations,
        project_root=project_root,
    )
    disputed_rejected = disputed_codes == ["CONTRACT_SCOPE_DISPUTED"] &&
        rejects_with_code(
            () -> ERIEC._assert_cert_scope_binding(
                disputed_probe,
                disputed_registry,
                manifest;
                catalog_declarations=catalog_declarations,
                project_root=project_root,
            ),
            "CONTRACT_SCOPE_DISPUTED",
        )
    record_a2_falsification(8, disputed_rejected)

    missing_registry = deepcopy(registry)
    pop!(missing_registry["contract"])
    extra_registry = deepcopy(registry)
    push!(extra_registry["contract"], Dict{String,Any}(
        "id" => "synthetic.extra-contract",
        "scope_kind" => "context_local",
    ))
    missing_codes = ERIEC.cert_scope_registry_violation_codes(
        missing_registry,
        manifest;
        catalog_declarations=catalog_declarations,
        project_root=project_root,
    )
    extra_codes = ERIEC.cert_scope_registry_violation_codes(
        extra_registry,
        manifest;
        catalog_declarations=catalog_declarations,
        project_root=project_root,
    )
    record_a2_falsification(
        9,
        missing_codes == ["SCOPE_REGISTRY_ID_MISMATCH"] &&
            extra_codes == ["SCOPE_REGISTRY_ID_MISMATCH"],
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
        @test valid_audit.contract_scope_ok
        @test isempty(valid_audit.contract_scope_violations)

        forbidden_path = joinpath(temporary_directory, "permanent.json")
        open(forbidden_path, "w") do io
            JSON3.write(io, merge(envelope, (claim_scope=:permanent,)))
        end
        forbidden_audit = certified_json_artifact_audit(forbidden_path)
        @test !forbidden_audit.ok
        @test !forbidden_audit.claim_scope_ok
        @test forbidden_audit.claim_scope_violations == ["CERT_SCOPE_FORBIDDEN"]

        exceeds_path = joinpath(temporary_directory, "exceeds.json")
        open(exceeds_path, "w") do io
            JSON3.write(io, merge(
                local_envelope,
                (claim_scope=:cross_context_conditional,),
            ))
        end
        exceeds_audit = certified_json_artifact_audit(exceeds_path)
        @test !exceeds_audit.ok
        @test exceeds_audit.claim_scope_ok
        @test !exceeds_audit.contract_scope_ok
        @test exceeds_audit.contract_scope_violations ==
            ["CLAIM_SCOPE_EXCEEDS_CONTRACT"]
    end
end
