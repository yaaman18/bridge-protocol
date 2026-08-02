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

    covers_declaration(claim, legacy_vp) =
        claim["lean_decl"] == legacy_vp["lean_decl"] ||
        startswith(claim["lean_decl"], legacy_vp["lean_decl"] * ".")

    function expected_exact_coverage(legacy_vp, claim_index, children)
        Set(
            claim_id
            for claim_id in children
            if haskey(claim_index, claim_id) &&
               covers_declaration(claim_index[claim_id], legacy_vp)
        )
    end

    function exact_coverage_matches_expected(coverage, legacy_vp, claim_index, children)
        get(coverage, "basis", nothing) == "exact_ledger_decl" || return true
        covers = get(coverage, "covers_claim_ids", nothing)
        covers isa AbstractVector || return false
        Set(covers) == expected_exact_coverage(legacy_vp, claim_index, children)
    end

    function complete_coverage_partitions_children(coverage, children)
        get(coverage, "audit_status", nothing) == "complete" || return true
        covers = get(coverage, "covers_claim_ids", nothing)
        not_covered = get(coverage, "not_covered_claim_ids", nothing)
        covers isa AbstractVector || return false
        not_covered isa AbstractVector || return false
        union(Set(covers), Set(not_covered)) == Set(children)
    end

    function complete_row_matches_vp(coverage, vp_index)
        get(coverage, "audit_status", nothing) == "complete" || return true
        legacy_vp_id = get(coverage, "legacy_vp_id", nothing)
        haskey(vp_index, legacy_vp_id) &&
            get(vp_index[legacy_vp_id], "coverage_audit", nothing) == "complete"
    end

    function complete_vps_have_rows(vp_index, coverages)
        coverage_by_vp = Dict(
            get(coverage, "legacy_vp_id", nothing) => coverage
            for coverage in coverages
        )
        all(values(vp_index)) do vp
            get(vp, "coverage_audit", nothing) == "complete" || return true
            haskey(coverage_by_vp, vp["id"]) &&
                get(coverage_by_vp[vp["id"]], "audit_status", nothing) == "complete"
        end
    end

    function legacy_vp_ids_unique(coverages)
        legacy_vp_ids = [get(coverage, "legacy_vp_id", nothing) for coverage in coverages]
        length(legacy_vp_ids) == length(unique(legacy_vp_ids))
    end

    function coverage_sets_disjoint(coverage)
        covers = get(coverage, "covers_claim_ids", nothing)
        not_covered = get(coverage, "not_covered_claim_ids", nothing)
        covers isa AbstractVector || return false
        not_covered isa AbstractVector || return false
        isempty(intersect(Set(covers), Set(not_covered)))
    end

    function not_covered_within_children(coverage, children)
        not_covered = get(coverage, "not_covered_claim_ids", nothing)
        not_covered isa AbstractVector || return false
        all(claim_id -> claim_id in children, not_covered)
    end

    function type_review_has_evidence(coverage, root)
        get(coverage, "basis", nothing) == "type_review" || return true
        reviewer = get(coverage, "reviewer", nothing)
        basis_log = get(coverage, "basis_log", nothing)
        reviewer isa AbstractString && !isempty(strip(reviewer)) || return false
        basis_log isa AbstractString && !isempty(strip(basis_log)) || return false
        !isabspath(basis_log) && isfile(normpath(joinpath(root, basis_log)))
    end

    for vp in ledger["vp"]
        if vp["status"] == "certified"
            @test haskey(vp, "coverage_audit")
            @test get(vp, "coverage_audit", nothing) in allowed_coverage_audits
        end
    end

    legacy_coverages = get(ledger, "legacy_coverage", Any[])
    @test legacy_vp_ids_unique(legacy_coverages)
    for coverage in legacy_coverages
        @test coverage_sets_disjoint(coverage)

        legacy_vp = vps_by_id[coverage["legacy_vp_id"]]
        children = legacy_children(coverage["legacy_vp_id"])
        @test exact_coverage_matches_expected(
            coverage,
            legacy_vp,
            claims_by_id,
            children,
        )
        @test complete_coverage_partitions_children(coverage, children)
        @test complete_row_matches_vp(coverage, vps_by_id)
        @test not_covered_within_children(
            coverage,
            children,
        )

        if get(coverage, "basis", nothing) == "type_review"
            @test type_review_has_evidence(coverage, project_root)
        end
    end
    @test complete_vps_have_rows(vps_by_id, legacy_coverages)

    @test !legacy_vp_ids_unique([
        Dict("legacy_vp_id" => "VP-DUPLICATE"),
        Dict("legacy_vp_id" => "VP-DUPLICATE"),
    ])
    @test !coverage_sets_disjoint(Dict(
        "covers_claim_ids" => ["CLM-OVERLAP"],
        "not_covered_claim_ids" => ["CLM-OVERLAP"],
    ))
    @test !not_covered_within_children(
        Dict("not_covered_claim_ids" => ["CLM-OUTSIDE"]),
        Set(["CLM-INSIDE"]),
    )
    @test !type_review_has_evidence(Dict("basis" => "type_review"), project_root)
    synthetic_vp = Dict("id" => "VP-SYNTHETIC", "lean_decl" => "ERIEC.Synthetic.Root")
    synthetic_claims = Dict(
        "CLM-EQUAL" => Dict("lean_decl" => "ERIEC.Synthetic.Root"),
        "CLM-COMPONENT" => Dict("lean_decl" => "ERIEC.Synthetic.Root.field"),
        "CLM-UNRELATED" => Dict("lean_decl" => "ERIEC.Other.Root"),
    )
    @test covers_declaration(synthetic_claims["CLM-EQUAL"], synthetic_vp)
    @test covers_declaration(synthetic_claims["CLM-COMPONENT"], synthetic_vp)
    @test !covers_declaration(synthetic_claims["CLM-UNRELATED"], synthetic_vp)
    @test expected_exact_coverage(
        synthetic_vp,
        synthetic_claims,
        Set(["CLM-COMPONENT"]),
    ) == Set(["CLM-COMPONENT"])
    @test !exact_coverage_matches_expected(
        Dict("basis" => "exact_ledger_decl", "covers_claim_ids" => Any[]),
        synthetic_vp,
        synthetic_claims,
        Set(["CLM-EQUAL"]),
    )
    @test !complete_coverage_partitions_children(
        Dict(
            "audit_status" => "complete",
            "covers_claim_ids" => ["CLM-EQUAL"],
            "not_covered_claim_ids" => Any[],
        ),
        Set(["CLM-EQUAL", "CLM-UNRELATED"]),
    )
    @test !complete_row_matches_vp(
        Dict("audit_status" => "complete", "legacy_vp_id" => "VP-SYNTHETIC"),
        Dict("VP-SYNTHETIC" => Dict(
            "id" => "VP-SYNTHETIC",
            "coverage_audit" => "unreviewed",
        )),
    )
    @test !complete_vps_have_rows(
        Dict("VP-SYNTHETIC" => Dict(
            "id" => "VP-SYNTHETIC",
            "coverage_audit" => "complete",
        )),
        Any[],
    )

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
                @test covers_declaration(claim, legacy_vp)
                @test contract.lean_name == last(split(legacy_vp["lean_decl"], '.'))
                @test claim_path in source_paths
            end
        end
    end
end
