using TOML
using Test
using ERIEC
using SHA

include("checker_sensitivity_cases.jl")

const CHECKER_RELATION_VALUES = Set([
    "exact_finite_decision",
    "sound_only",
    "complete_only",
    "witness_validator",
    "counterexample_generator",
    "counterexample_validator",
    "observation_only",
    "regression_only",
    "lean_only",
    "unclassified",
])

function valid_checker_semantic_row(row)
    relation = get(row, "checker_relation", "")
    relation in CHECKER_RELATION_VALUES || return false
    review_status = get(row, "review_status", "")
    if relation == "unclassified"
        return review_status == "unreviewed"
    end
    if relation == "lean_only"
        return review_status == "machine_verified"
    end
    review_status == "reviewed" || return false
    required = [
        "checker",
        "lean_decl",
        "scope",
        "assumptions",
        "guarantee",
        "reviewer",
        "basis_log",
    ]
    all(key -> haskey(row, key) && !isempty(row[key]), required)
end

checker_relation_matches_contract(row, contract) =
    (row["checker_relation"] == "lean_only") ==
    (contract.julia_checker === nothing)

@testset "checker semantic manifest" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    manifest = TOML.parsefile(
        joinpath(project_root, "specs", "checker-semantic-manifest.toml"),
    )
    rows = manifest["contract"]
    ids = [row["id"] for row in rows]
    artifact = lean_certified_artifact(; project_root=project_root)
    artifact_ids = certified_artifact_contract_ids(artifact)
    contracts_by_id = Dict(contract.id => contract for contract in artifact.contracts)

    @test manifest["schema_version"] == 2
    @test Set(manifest["allowed_relations"]) == CHECKER_RELATION_VALUES
    @test allunique(ids)
    @test Set(ids) == Set(artifact_ids)
    @test length(rows) == length(artifact_ids) == 157
    @test all(valid_checker_semantic_row, rows)
    @test all(
        row -> checker_relation_matches_contract(row, contracts_by_id[row["id"]]),
        rows,
    )

    reviewed = filter(row -> row["review_status"] == "reviewed", rows)
    @test count(row -> row["checker_relation"] == "lean_only", rows) == 71
    reviewed_relations = Dict(row["id"] => row["checker_relation"] for row in reviewed)
    pilot_relations = Dict(
        "adjunction.rigidity" => "exact_finite_decision",
        "adjunction.galois_conn" => "regression_only",
        "world.lambda_max" => "observation_only",
        "worlddc.no_unconditional_equivalence" => "sound_only",
        "worlddc.no_backward_unconditional" => "counterexample_validator",
    )
    @test all(
        get(reviewed_relations, id, nothing) == relation
        for (id, relation) in pilot_relations
    )
    @test all(row -> isfile(joinpath(project_root, row["basis_log"])), reviewed)

    sensitivity_path = joinpath(project_root, manifest["sensitivity_registry"])
    sensitivity_hash = bytes2hex(sha256(read(sensitivity_path)))
    @test sensitivity_hash == manifest["sensitivity_registry_sha256"]
    sensitivity_cases = checker_sensitivity_cases()
    exact_rows = filter(row -> row["checker_relation"] == "exact_finite_decision", rows)
    @test Set(keys(sensitivity_cases)) == Set(row["id"] for row in exact_rows)
    rows_by_id = Dict(row["id"] => row for row in rows)
    @test all(
        case -> case.negative_kind in CHECKER_SENSITIVITY_NEGATIVE_KINDS,
        values(sensitivity_cases),
    )
    for (id, case) in sensitivity_cases
        @test case.positive()
        @test !case.negative()
        if case.tolerance_assumption !== nothing
            @test case.tolerance_assumption in rows_by_id[id]["assumptions"]
        end
    end

    synthetic = Dict{String,Any}(
        "id" => "synthetic",
        "review_status" => "reviewed",
        "checker" => "synthetic_checker",
        "lean_decl" => "ERIEC.Synthetic.claim",
        "scope" => "synthetic finite scope",
        "assumptions" => ["synthetic assumption"],
        "guarantee" => "synthetic guarantee",
        "reviewer" => "test",
        "basis_log" => "synthetic.log",
    )
    for relation in setdiff(
        CHECKER_RELATION_VALUES,
        Set(["lean_only", "unclassified"]),
    )
        row = merge(synthetic, Dict("checker_relation" => relation))
        @test valid_checker_semantic_row(row)
    end
    @test valid_checker_semantic_row(Dict(
        "id" => "synthetic-lean-only",
        "checker_relation" => "lean_only",
        "review_status" => "machine_verified",
    ))
    @test valid_checker_semantic_row(Dict(
        "id" => "synthetic-unclassified",
        "checker_relation" => "unclassified",
        "review_status" => "unreviewed",
    ))
    @test !valid_checker_semantic_row(merge(
        synthetic,
        Dict("checker_relation" => "unclassified"),
    ))
    @test !valid_checker_semantic_row(merge(
        synthetic,
        Dict("checker_relation" => "unknown"),
    ))

    checker_present = (julia_checker=:synthetic_checker,)
    checker_absent = (julia_checker=nothing,)
    lean_only_row = Dict("checker_relation" => "lean_only")
    classified_row = Dict("checker_relation" => "regression_only")
    @test checker_relation_matches_contract(lean_only_row, checker_absent)
    @test checker_relation_matches_contract(classified_row, checker_present)
    @test !checker_relation_matches_contract(lean_only_row, checker_present)
    @test !checker_relation_matches_contract(classified_row, checker_absent)
end
