using TOML
using Test
using ERIEC

const CHECKER_RELATION_VALUES = Set([
    "exact_finite_decision",
    "sound_only",
    "complete_only",
    "witness_validator",
    "counterexample_generator",
    "counterexample_validator",
    "observation_only",
    "regression_only",
    "unclassified",
])

function valid_checker_semantic_row(row)
    relation = get(row, "checker_relation", "")
    relation in CHECKER_RELATION_VALUES || return false
    review_status = get(row, "review_status", "")
    if relation == "unclassified"
        return review_status == "unreviewed"
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

@testset "checker semantic manifest" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    manifest = TOML.parsefile(
        joinpath(project_root, "specs", "checker-semantic-manifest.toml"),
    )
    rows = manifest["contract"]
    ids = [row["id"] for row in rows]
    artifact_ids = certified_artifact_contract_ids(
        lean_certified_artifact(; project_root=project_root),
    )

    @test manifest["schema_version"] == 1
    @test Set(manifest["allowed_relations"]) == CHECKER_RELATION_VALUES
    @test allunique(ids)
    @test Set(ids) == Set(artifact_ids)
    @test length(rows) == length(artifact_ids) == 157
    @test all(valid_checker_semantic_row, rows)

    reviewed = filter(row -> row["review_status"] == "reviewed", rows)
    @test length(reviewed) == 5
    @test count(row -> row["checker_relation"] == "unclassified", rows) == 152
    @test Dict(row["id"] => row["checker_relation"] for row in reviewed) == Dict(
        "adjunction.rigidity" => "exact_finite_decision",
        "adjunction.galois_conn" => "exact_finite_decision",
        "world.lambda_max" => "observation_only",
        "worlddc.no_unconditional_equivalence" => "regression_only",
        "worlddc.no_backward_unconditional" => "counterexample_validator",
    )
    @test all(row -> isfile(joinpath(project_root, row["basis_log"])), reviewed)

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
    for relation in setdiff(CHECKER_RELATION_VALUES, Set(["unclassified"]))
        row = merge(synthetic, Dict("checker_relation" => relation))
        @test valid_checker_semantic_row(row)
    end
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
end
