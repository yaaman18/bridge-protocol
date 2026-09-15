isdefined(@__MODULE__, :AssumptionSuiteAudit) || include("AssumptionSuiteAudit.jl")

module ConstraintOverlayAudit

import ..AssumptionSuiteAudit
using SHA

const ONE_INPUT_SOURCE = "formal-experiments/OneInputAdjunction.lean"
const ONE_INPUT_SOURCE_SHA256 = "1d7030a44002e3cb220d44e32d529e513bacf290ba7d4c7397179ed8f9f53c3c"

function _constraint_catalog()
    source_path = normpath(joinpath(@__DIR__, "..", ONE_INPUT_SOURCE))
    isfile(source_path) || throw(ArgumentError("formal experiment source is missing"))
    digest = bytes2hex(sha256(read(source_path)))
    digest == ONE_INPUT_SOURCE_SHA256 ||
        throw(ArgumentError("formal experiment source changed; recheck before updating the constraint"))
    constraints = [Dict{String,Any}(
        "constraint_id"=>"one-input-gc-self-implies-smc-and-act",
        "context"=>"one_input_one_motor_P6_H6_L4_R4",
        "premises"=>Dict("adjunction"=>true, "nondegenerate"=>true, "hSelf"=>true),
        "conclusions"=>Dict("hSMC"=>true, "hAct"=>true),
        "lean_decl"=>"ERIEC.ModelAuditExperiment.one_input_gc_self_implies_smc_and_act",
        "source"=>ONE_INPUT_SOURCE,
        "source_sha256"=>digest,
        "evidence_class"=>"lean_checked_experiment",
        "certificate_registered"=>false,
        "default_target"=>false)]
    constraints
end

function _overlay_target(suite, target, constraints)
    valuation = Dict{String,Bool}()
    merge!(valuation, suite["fixed_conditions"])
    merge!(valuation, target["expected"])
    applicable = [constraint for constraint in constraints
                  if constraint["context"] == suite["context"] &&
                     all(haskey(valuation, key) && valuation[key] == value
                         for (key, value) in constraint["premises"])]
    conflicts = Dict{String,Any}[]
    unknown_conclusions = Dict{String,Any}[]
    for constraint in applicable
        unknown = sort!([key for key in keys(constraint["conclusions"]) if !haskey(valuation, key)])
        isempty(unknown) || push!(unknown_conclusions, Dict{String,Any}(
            "constraint_id"=>constraint["constraint_id"], "conclusions"=>unknown,
            "lean_decl"=>constraint["lean_decl"]))
        violated = sort!([key for (key, value) in constraint["conclusions"]
                          if haskey(valuation, key) && valuation[key] != value])
        isempty(violated) || push!(conflicts, Dict(
            "constraint_id"=>constraint["constraint_id"],
            "violated_conclusions"=>violated,
            "lean_decl"=>constraint["lean_decl"]))
    end
    witness_found = target["status"] == "witness_found"
    classification = if witness_found && !isempty(conflicts)
        "conflict_requires_review"
    elseif !witness_found && !isempty(conflicts)
        "incompatible_with_checked_experimental_statement"
    elseif witness_found
        "witness_found"
    else
        "not_found_in_finite_catalog"
    end
    Dict{String,Any}(
        "scenario"=>suite["scenario"],
        "context"=>suite["context"],
        "target"=>target["target"],
        "catalog_status"=>target["status"],
        "witnesses"=>target["witnesses"],
        "applicable_constraints"=>sort!(getindex.(applicable, "constraint_id")),
        "constraint_conflicts"=>conflicts,
        "unknown_conclusions"=>unknown_conclusions,
        "constraint_check_complete"=>isempty(unknown_conclusions),
        "classification"=>classification,
        "certificate_registered"=>false,
        "general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified")
end

function constraint_overlay_report(suite_report=AssumptionSuiteAudit.assumption_suite_report())
    constraints = _constraint_catalog()
    rows = [_overlay_target(suite, target, constraints)
            for suite in suite_report["suites"] for target in suite["targets"]]
    Dict{String,Any}(
        "schema_version"=>1,
        "constraint_count"=>length(constraints),
        "target_count"=>length(rows),
        "constraints"=>constraints,
        "targets"=>rows,
        "conflict_count"=>count(row -> row["classification"] == "conflict_requires_review", rows),
        "certificate_registered"=>false,
        "general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified",
        "execution_certified"=>false)
end

end
