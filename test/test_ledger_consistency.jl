using TOML
using Test
using ERIEC

@testset "v1 ledger coverage audit" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    ledger = TOML.parsefile(joinpath(project_root, "specs", "ledger.toml"))
    claim_ledger = TOML.parsefile(joinpath(project_root, "specs", "claim-ledger-v2.toml"))
    allowed_coverage_audits = Set(["unreviewed", "complete"])
    allowed_coverage_bases = Set(["exact_ledger_decl", "type_review"])

    vps_by_id = Dict(vp["id"] => vp for vp in ledger["vp"])
    claims_by_id = Dict(claim["id"] => claim for claim in claim_ledger["claim"])
    groups = claim_ledger["claim_group"]
    artifact = ERIEC.lean_certified_artifact(; project_root)
    contracts_by_id = Dict(contract.id => contract for contract in artifact.contracts)

    function legacy_children(legacy_vp_id)
        Set(
            child
            for group in groups
            if legacy_vp_id in get(group, "legacy_vp_ids", Any[])
            for child in group["children"]
        )
    end

    for vp in ledger["vp"]
        if vp["status"] == "certified"
            @test haskey(vp, "coverage_audit")
            @test get(vp, "coverage_audit", nothing) in allowed_coverage_audits
        end
    end

    for coverage in get(ledger, "legacy_coverage", Any[])
        legacy_vp_id = coverage["legacy_vp_id"]
        contract_id = coverage["contract_id"]
        covers_claim_ids = get(coverage, "covers_claim_ids", nothing)
        not_covered_claim_ids = get(coverage, "not_covered_claim_ids", nothing)

        @test get(coverage, "audit_status", nothing) in allowed_coverage_audits
        @test get(coverage, "basis", nothing) in allowed_coverage_bases
        @test covers_claim_ids isa AbstractVector
        @test not_covered_claim_ids isa AbstractVector
        @test haskey(vps_by_id, legacy_vp_id)
        @test haskey(contracts_by_id, contract_id)

        if !(covers_claim_ids isa AbstractVector) ||
                !(not_covered_claim_ids isa AbstractVector) ||
                !haskey(vps_by_id, legacy_vp_id) ||
                !haskey(contracts_by_id, contract_id)
            continue
        end

        for claim_id in union(covers_claim_ids, not_covered_claim_ids)
            @test haskey(claims_by_id, claim_id)
        end

        if coverage["basis"] == "exact_ledger_decl"
            legacy_vp = vps_by_id[legacy_vp_id]
            contract = contracts_by_id[contract_id]
            children = legacy_children(legacy_vp_id)
            source_paths = Set(ERIEC._module_source_paths(project_root, contract.lean_module))

            @test contract_id == legacy_vp["contract_id"]
            for claim_id in covers_claim_ids
                haskey(claims_by_id, claim_id) || continue
                claim = claims_by_id[claim_id]
                claim_path = normpath(joinpath(project_root, claim["lean_file"]))

                @test claim_id in children
                @test claim["lean_decl"] == legacy_vp["lean_decl"]
                @test contract.lean_name == last(split(legacy_vp["lean_decl"], '.'))
                @test claim_path in source_paths
            end
        end
    end
end
