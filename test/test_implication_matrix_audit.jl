using Test
using TOML
isdefined(@__MODULE__, :ImplicationMatrixAudit) ||
    include(joinpath(@__DIR__, "..", "tools", "ImplicationMatrixAudit.jl"))

const MATRIX_P3 = "two_inputs_two_motors_P3_H6_L4_R4"
const MATRIX_P6_ONE = "one_input_one_motor_P6_H6_L4_R4"
const MATRIX_P6_TWO = "one_input_two_motors_P6_H6_L4_R4"

@testset "context-specific implication matrix does not promote finite absence" begin
    report = ImplicationMatrixAudit.implication_matrix_report()
    @test report["context_count"] == 3
    @test report["cell_count"] == 3 * 12 * 11
    @test all(block["cell_count"] == 12 * 11 for block in report["contexts"])
    @test sort(getindex.(report["contexts"], "model_count")) == [1, 5, 7]
    @test !report["implication_proved"]
    @test report["general_impossibility"] == "not_established"
    @test report["phenomenal_claim"] == "not_certified"

    self_smc = ImplicationMatrixAudit.find_implication(report, MATRIX_P3, :hSelf, :hSMC)
    @test self_smc["status"] == "counterexample_found"
    @test self_smc["countermodels"] == ["p3-adjoint-without_hSMC"]
    dc_max = ImplicationMatrixAudit.find_implication(report, MATRIX_P3, :all_dc, :kappa_equals_nu)
    @test dc_max["status"] == "counterexample_found"
    @test "p3-adjoint-support-expansion" in dc_max["countermodels"]

    one_active = ImplicationMatrixAudit.find_implication(report, MATRIX_P6_ONE, :all_dc, :active_boundary)
    @test one_active["status"] == "no_counterexample_in_finite_catalog"
    @test !one_active["implication_proved"] && one_active["premise_model_count"] == 1
    no_premise = ImplicationMatrixAudit.find_implication(report, MATRIX_P6_TWO, :adjunction, :hSelf)
    @test no_premise["status"] == "premise_uninstantiated_in_finite_catalog"
    @test no_premise["known_model_count"] == 5 && no_premise["premise_model_count"] == 0
    unobserved = ImplicationMatrixAudit.find_implication(
        report, MATRIX_P6_TWO, :candidate_selection_obstructed, :hSelf)
    @test unobserved["status"] == "predicate_unobserved_in_context"
    @test unobserved["unknown_model_count"] == 5
    @test_throws ArgumentError ImplicationMatrixAudit.find_implication(report, MATRIX_P3, :hSelf, :hSelf)

    for block in report["contexts"], cell in block["cells"]
        @test !cell["implication_proved"]
        @test cell["context"] == block["context"]
        @test cell["context_model_count"] == block["model_count"]
        @test cell["known_model_count"] + cell["unknown_model_count"] == block["model_count"]
        @test cell["countermodel_count"] <= cell["premise_model_count"] <= cell["known_model_count"]
    end

    mktempdir() do dir
        root = dirname(@__DIR__)
        cli = joinpath(root, "bin", "eriec-implication-matrix-audit.jl")
        output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli matrix`, String)
        parsed = TOML.parse(output)
        @test parsed["cell_count"] == report["cell_count"]
        @test parsed["matrix_scope"] == "single_positive_premise_to_positive_conclusion"
        @test !parsed["implication_proved"]
    end
end
