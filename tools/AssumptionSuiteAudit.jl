isdefined(@__MODULE__, :CountermodelAudit) || include("CountermodelAudit.jl")

module AssumptionSuiteAudit

import ..CountermodelAudit

const DC_KEYS = ("hSelf", "hSMC", "hAct", "hBound")
const TARGETS = (
    (name="all_four", values=(true, true, true, true)),
    (name="without_hSelf", values=(false, true, true, true)),
    (name="without_hSMC", values=(true, false, true, true)),
    (name="without_hAct", values=(true, true, false, true)),
    (name="without_hBound", values=(true, true, true, false)))
const SCENARIOS = (
    (id="p3-adjunction", context="two_inputs_two_motors_P3_H6_L4_R4",
     conditions=("adjunction"=>true, "nondegenerate"=>true)),
    (id="p6-one-input-adjunction", context="one_input_one_motor_P6_H6_L4_R4",
     conditions=("adjunction"=>true, "nondegenerate"=>true)),
    (id="p6-two-motor-no-adjunction", context="one_input_two_motors_P6_H6_L4_R4",
     conditions=("adjunction"=>false, "nondegenerate"=>true)))

function _target_row(target, context_rows, conditions)
    required = (conditions..., (DC_KEYS[i]=>target.values[i] for i in eachindex(DC_KEYS))...)
    known = [row for row in context_rows if all(haskey(row["observations"], key) for (key, _) in required)]
    unknown = sort!([row["id"] for row in context_rows if row ∉ known])
    matching = sort!([row["id"] for row in known
                      if all(row["observations"][key] == value for (key, value) in required)])
    Dict{String,Any}(
        "target"=>target.name,
        "expected"=>Dict(DC_KEYS[i]=>target.values[i] for i in eachindex(DC_KEYS)),
        "known_model_count"=>length(known),
        "unknown_model_count"=>length(unknown),
        "unknown_models"=>unknown,
        "witness_count"=>length(matching),
        "witnesses"=>matching,
        "status"=>isempty(matching) ? "not_found_in_finite_catalog" : "witness_found",
        "general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified")
end

function assumption_suite_report(catalog=CountermodelAudit.finite_model_catalog())
    suites = Dict{String,Any}[]
    for scenario in SCENARIOS
        context_rows = [row for row in catalog["models"] if row["context"] == scenario.context]
        isempty(context_rows) && error("assumption-suite context is absent from the catalog")
        targets = [_target_row(target, context_rows, scenario.conditions) for target in TARGETS]
        push!(suites, Dict{String,Any}(
            "scenario"=>scenario.id,
            "context"=>scenario.context,
            "context_model_count"=>length(context_rows),
            "fixed_conditions"=>Dict(scenario.conditions),
            "target_count"=>length(targets),
            "witnessed_target_count"=>count(row -> row["status"] == "witness_found", targets),
            "complete_five_pattern_suite"=>all(row -> row["status"] == "witness_found", targets),
            "targets"=>targets))
    end
    Dict{String,Any}(
        "schema_version"=>1,
        "definition"=>"dc_four_predicates_boolean_v1",
        "predicate_order"=>collect(DC_KEYS),
        "catalog_scope"=>catalog["catalog_scope"],
        "scenario_count"=>length(suites),
        "suites"=>suites,
        "full_M1_M4"=>"not_established",
        "general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified",
        "execution_certified"=>false)
end

end
