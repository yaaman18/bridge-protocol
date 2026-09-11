isdefined(@__MODULE__, :CountermodelAudit) || include("CountermodelAudit.jl")

module ImplicationMatrixAudit

import ..CountermodelAudit

const MATRIX_SCOPE = "single_positive_premise_to_positive_conclusion"

function _implication_cell(context::String, premise::Symbol, conclusion::Symbol, rows)
    pkey, ckey = String(premise), String(conclusion)
    known = [row for row in rows if haskey(row["observations"], pkey) &&
                                      haskey(row["observations"], ckey)]
    unknown = sort!([row["id"] for row in rows if !haskey(row["observations"], pkey) ||
                                                   !haskey(row["observations"], ckey)])
    instantiated = [row for row in known if row["observations"][pkey]]
    countermodels = sort!([row["id"] for row in instantiated if !row["observations"][ckey]])
    status = if isempty(known)
        :predicate_unobserved_in_context
    elseif isempty(instantiated)
        :premise_uninstantiated_in_finite_catalog
    elseif !isempty(countermodels)
        :counterexample_found
    else
        :no_counterexample_in_finite_catalog
    end
    Dict{String,Any}(
        "context"=>context,
        "premise"=>pkey,
        "premise_value"=>true,
        "conclusion"=>ckey,
        "conclusion_value"=>true,
        "status"=>String(status),
        "context_model_count"=>length(rows),
        "known_model_count"=>length(known),
        "unknown_model_count"=>length(unknown),
        "unknown_models"=>unknown,
        "premise_model_count"=>length(instantiated),
        "countermodel_count"=>length(countermodels),
        "countermodels"=>countermodels,
        "implication_proved"=>false,
        "general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified")
end

function implication_matrix_report(catalog=CountermodelAudit.finite_model_catalog())
    predicates = sort!(collect(CountermodelAudit.QUERY_PREDICATES); by=String)
    context_names = sort!(unique(String(row["context"]) for row in catalog["models"]))
    contexts = Dict{String,Any}[]
    for context in context_names
        rows = [row for row in catalog["models"] if row["context"] == context]
        cells = [_implication_cell(context, premise, conclusion, rows)
                 for premise in predicates for conclusion in predicates if premise != conclusion]
        status_counts = Dict(status=>count(cell -> cell["status"] == status, cells) for status in
            ("counterexample_found", "no_counterexample_in_finite_catalog",
             "premise_uninstantiated_in_finite_catalog", "predicate_unobserved_in_context"))
        push!(contexts, Dict("context"=>context, "model_count"=>length(rows),
            "cell_count"=>length(cells), "status_counts"=>status_counts, "cells"=>cells))
    end
    Dict{String,Any}(
        "schema_version"=>1,
        "catalog_scope"=>catalog["catalog_scope"],
        "matrix_scope"=>MATRIX_SCOPE,
        "predicates"=>String.(predicates),
        "context_count"=>length(contexts),
        "cell_count"=>sum(context["cell_count"] for context in contexts),
        "contexts"=>contexts,
        "implication_proved"=>false,
        "general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified",
        "execution_certified"=>false)
end

function find_implication(report::AbstractDict, context::AbstractString,
                          premise::Union{Symbol,AbstractString},
                          conclusion::Union{Symbol,AbstractString})
    pkey, ckey = String(premise), String(conclusion)
    matches = [cell for block in report["contexts"] if block["context"] == context
                    for cell in block["cells"]
                    if cell["premise"] == pkey && cell["conclusion"] == ckey]
    length(matches) == 1 || throw(ArgumentError("implication cell is absent or ambiguous"))
    only(matches)
end

end
