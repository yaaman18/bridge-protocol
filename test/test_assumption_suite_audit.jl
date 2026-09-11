using Test
using TOML
isdefined(@__MODULE__, :AssumptionSuiteAudit) ||
    include(joinpath(@__DIR__, "..", "tools", "AssumptionSuiteAudit.jl"))

@testset "all-four and isolated-drop suites remain background-specific" begin
    report = AssumptionSuiteAudit.assumption_suite_report()
    @test report["scenario_count"] == 3
    @test report["predicate_order"] == ["hSelf", "hSMC", "hAct", "hBound"]
    @test report["full_M1_M4"] == "not_established"
    @test report["general_impossibility"] == "not_established"
    @test report["phenomenal_claim"] == "not_certified"

    suites = Dict(row["scenario"]=>row for row in report["suites"])
    p3 = suites["p3-adjunction"]
    @test p3["complete_five_pattern_suite"]
    @test p3["witnessed_target_count"] == 5
    @test p3["fixed_conditions"] == Dict("adjunction"=>true, "nondegenerate"=>true)
    @test all(row["witness_count"] >= 1 for row in p3["targets"])

    p6_dropped = suites["p6-two-motor-no-adjunction"]
    @test p6_dropped["complete_five_pattern_suite"]
    @test p6_dropped["witnessed_target_count"] == 5
    @test p6_dropped["fixed_conditions"]["adjunction"] == false

    p6_one = suites["p6-one-input-adjunction"]
    @test !p6_one["complete_five_pattern_suite"]
    @test p6_one["witnessed_target_count"] == 1
    by_target = Dict(row["target"]=>row for row in p6_one["targets"])
    @test by_target["all_four"]["status"] == "witness_found"
    @test all(by_target[name]["status"] == "not_found_in_finite_catalog"
              for name in ("without_hSelf", "without_hSMC", "without_hAct", "without_hBound"))
    @test all(row["general_impossibility"] == "not_established" for row in p6_one["targets"])

    for suite in values(suites), row in suite["targets"]
        expected = row["expected"]
        @test length(expected) == 4
        @test count(!, values(expected)) <= 1
        @test row["known_model_count"] + row["unknown_model_count"] == suite["context_model_count"]
    end

    root = dirname(@__DIR__)
    cli = joinpath(root, "bin", "eriec-assumption-suite-audit.jl")
    output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli suites`, String)
    parsed = TOML.parse(output)
    @test parsed["scenario_count"] == 3
    @test !parsed["execution_certified"]
end
