using Test
using TOML
isdefined(@__MODULE__, :ConstraintOverlayAudit) ||
    include(joinpath(@__DIR__, "..", "tools", "ConstraintOverlayAudit.jl"))

@testset "checked experimental constraints remain distinct from finite absence" begin
    suites = AssumptionSuiteAudit.assumption_suite_report()
    report = ConstraintOverlayAudit.constraint_overlay_report(suites)
    @test report["constraint_count"] == 1
    @test report["target_count"] == 15
    @test report["conflict_count"] == 0
    @test all(row["constraint_check_complete"] && isempty(row["unknown_conclusions"])
              for row in report["targets"])
    @test !report["certificate_registered"] && !report["execution_certified"]
    @test report["general_impossibility"] == "not_established"
    constraint = only(report["constraints"])
    @test constraint["source_sha256"] == ConstraintOverlayAudit.ONE_INPUT_SOURCE_SHA256
    @test constraint["evidence_class"] == "lean_checked_experiment"
    @test !constraint["certificate_registered"] && !constraint["default_target"]

    rows = Dict((row["scenario"], row["target"])=>row for row in report["targets"])
    for target in ("without_hSMC", "without_hAct")
        row = rows[("p6-one-input-adjunction", target)]
        @test row["classification"] == "incompatible_with_checked_experimental_statement"
        @test length(row["constraint_conflicts"]) == 1
    end
    for target in ("without_hSelf", "without_hBound")
        row = rows[("p6-one-input-adjunction", target)]
        @test row["classification"] == "not_found_in_finite_catalog"
        @test isempty(row["constraint_conflicts"])
    end
    @test all(rows[("p3-adjunction", target)]["classification"] == "witness_found"
              for target in ("all_four", "without_hSelf", "without_hSMC", "without_hAct", "without_hBound"))
    @test all(isempty(rows[("p6-two-motor-no-adjunction", target)]["applicable_constraints"])
              for target in ("all_four", "without_hSelf", "without_hSMC", "without_hAct", "without_hBound"))

    conflicting = deepcopy(suites)
    one_suite = only(filter(row -> row["scenario"] == "p6-one-input-adjunction", conflicting["suites"]))
    smc = only(filter(row -> row["target"] == "without_hSMC", one_suite["targets"]))
    smc["status"] = "witness_found"
    smc["witnesses"] = ["synthetic-review-trigger"]
    conflict_report = ConstraintOverlayAudit.constraint_overlay_report(conflicting)
    conflict_row = only(filter(row -> row["scenario"] == "p6-one-input-adjunction" &&
                                     row["target"] == "without_hSMC", conflict_report["targets"]))
    @test conflict_report["conflict_count"] == 1
    @test conflict_row["classification"] == "conflict_requires_review"

    # Exercise an applicable constraint with a conclusion absent from the target.
    extra = deepcopy(constraint)
    extra["conclusions"]["unobserved_predicate"] = true
    for status in ("witness_found", "not_found_in_finite_catalog"), violates in (false, true)
        target = deepcopy(smc)
        target["status"] = status
        target["expected"]["hSMC"] = !violates
        row = ConstraintOverlayAudit._overlay_target(one_suite, target, [extra])
        @test !row["constraint_check_complete"]
        unknown = only(row["unknown_conclusions"])
        @test unknown["constraint_id"] == extra["constraint_id"]
        @test unknown["conclusions"] == ["unobserved_predicate"]
        @test isempty(row["constraint_conflicts"]) == !violates
        expected_class = violates ? (status == "witness_found" ? "conflict_requires_review" :
            "incompatible_with_checked_experimental_statement") : status
        @test row["classification"] == expected_class
    end
    not_applicable = deepcopy(extra)
    not_applicable["premises"]["unobserved_premise"] = true
    skipped = ConstraintOverlayAudit._overlay_target(one_suite, smc, [not_applicable])
    @test isempty(skipped["applicable_constraints"]) && isempty(skipped["unknown_conclusions"])
    @test skipped["constraint_check_complete"] # Scoped to applicable constraints only.

    root = dirname(@__DIR__)
    cli = joinpath(root, "bin", "eriec-constraint-overlay-audit.jl")
    parsed = TOML.parse(read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli overlay`, String))
    @test parsed["target_count"] == 15 && parsed["conflict_count"] == 0
    @test parsed["phenomenal_claim"] == "not_certified"
    @test all(haskey(row, "unknown_conclusions") && row["constraint_check_complete"] for row in parsed["targets"])
end
