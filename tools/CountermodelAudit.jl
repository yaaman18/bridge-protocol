isdefined(@__MODULE__, :ClosureAudit) || include("ClosureAudit.jl")

module CountermodelAudit

import ..ModelAudit
import ..BackgroundAudit
import ..ClosureAudit
using TOML
using ERIEC

const QUERY_PREDICATES = Set((:adjunction,:hSelf,:hSMC,:hAct,:hBound,:all_dc,
    :nondegenerate,:active_boundary,:kappa_subset_future,:kappa_subset_nu,
    :kappa_equals_nu,:candidate_selection_obstructed,
    :dc2,:hSelf2,:hHingeNeeded,:hUnit,:beta_nonempty))

# DC2 (formal-experiments/M1Refinement.lean, not ratified) read on the same model.
function _dc2_observations(model)
    d = ModelAudit.check_dc2(model)
    d.valid || error("DC2 observation on an invalid model")
    Dict{Symbol,Bool}(:dc2=>d.dc2,:hSelf2=>d.hSelf2,:hHingeNeeded=>d.hHingeNeeded,
        :hUnit=>d.hUnit,:beta_nonempty=>d.beta_nonempty)
end

function _observations(measured; selection_obstructed=nothing)
    closure = ClosureAudit.check_observed_closure(measured.model)
    background = BackgroundAudit.check_adjunction_background(measured.model)
    q = ModelAudit._audit_persist(measured.traces[0],measured.circuit.R,measured.circuit.units)
    actual = measured.result.actual
    values = Dict{Symbol,Bool}(:adjunction=>background.holds,:hSelf=>actual[1],:hSMC=>actual[2],
        :hAct=>actual[3],:hBound=>actual[4],:all_dc=>all(actual),
        :nondegenerate=>measured.result.nondegenerate,:active_boundary=>measured.active_boundary,
        :kappa_subset_future=>measured.model.kappa ⊆ q,:kappa_subset_nu=>closure.kappa_subset_nu,
        :kappa_equals_nu=>closure.kappa_equals_nu)
    selection_obstructed === nothing || (values[:candidate_selection_obstructed]=selection_obstructed)
    merge!(values,_dc2_observations(measured.model))
end

# Abstract models (relations set by hand, carriers need not overlap, no graph). Only predicates that
# the model decides are recorded:
# - hSelf, hSMC, hAct do not read the boundary, so ERIEC.check_DC decides them;
# - the graph-boundary hBound is decided only when the core is every constituent (then every graph
#   boundary is empty, whatever the graph); otherwise it is left unobserved;
# - all_dc is recorded only when some observed DC component is false.
# Circuit dynamics predicates (active_boundary, future, nu, selection) are unobserved.
function _abstract_observations(model)
    kappa, eps = Set{Symbol}(model.kappa), Set{Symbol}(model.epsilon)
    sys = ERIEC.ERIEState{Symbol,Symbol,Symbol,Nothing}(
        m->copy(model.alpha[m]),e->copy(model.sigma[e]),m->copy(model.pi[m]),c->copy(model.rho[c]),
        _->copy(kappa),_->copy(eps),Set{Symbol}(),nothing)
    r = ERIEC.check_DC(sys)
    values = Dict{Symbol,Bool}(:hSelf=>r.hSelf,:hSMC=>r.hSMC,:hAct=>r.hAct,
        :adjunction=>all(ERIEC.alpha_star(m->copy(model.alpha[m]),N) ⊆ X ==
                         (N ⊆ ERIEC.sigma_star(e->copy(model.sigma[e]),X))
                         for N in ERIEC.powerset(collect(model.M)) for X in ERIEC.powerset(collect(model.E))),
        :nondegenerate=>ModelAudit.dc2_nondegenerate(model))
    kappa == Set{Symbol}(model.C) && (values[:hBound]=false)
    (!r.hSelf || !r.hSMC || !r.hAct || get(values,:hBound,true) == false) && (values[:all_dc]=false)
    merge!(values,_dc2_observations(model))
end

function _abstract_row(id,context,model;origin)
    data = ModelAudit.dc2_model_dict(model)
    Dict{String,Any}("id"=>id,"context"=>context,"origin"=>origin,
        "model_digest"=>ModelAudit._audit_digest(data),"model"=>data,
        "observations"=>Dict(String(k)=>v for (k,v) in _abstract_observations(model)))
end

function _catalog_row(id,context,circuit,measured; selection_obstructed=nothing,origin)
    Dict{String,Any}("id"=>id,"context"=>context,"origin"=>origin,
        "circuit_digest"=>ModelAudit._audit_digest(ModelAudit.circuit_dict(circuit)),
        "circuit"=>ModelAudit.circuit_dict(circuit),
        "observations"=>Dict(String(k)=>v for (k,v) in _observations(measured;selection_obstructed)))
end

function finite_model_catalog()
    rows = Dict{String,Any}[]
    for witness in BackgroundAudit.adjoint_measured_witnesses()
        measured = ModelAudit.measure_circuit(witness.circuit)
        push!(rows,_catalog_row("p3-adjoint-"*witness.name,"two_inputs_two_motors_P3_H6_L4_R4",
            witness.circuit,measured;origin="explicit_P3_construction"))
    end
    expanded = ClosureAudit._support_expansion_witness()
    push!(rows,_catalog_row("p3-adjoint-support-expansion","two_inputs_two_motors_P3_H6_L4_R4",
        expanded,ModelAudit.measure_circuit(expanded);origin="modified_initial_P3"))
    union_data = TOML.parsefile(normpath(joinpath(@__DIR__,"..","logs","gates","RSB-AUDIT-008","symmetric-union-witness.toml")))
    union_circuit = ModelAudit.parse_audit_circuit(union_data["measurement"]["circuit"])
    push!(rows,_catalog_row("p3-adjoint-symmetric-union","two_inputs_two_motors_P3_H6_L4_R4",
        union_circuit,ModelAudit.measure_circuit(union_circuit);selection_obstructed=true,
        origin="symmetric_component_fixture"))
    old = ModelAudit.measured_dc_model()
    old_circuit = ModelAudit.AuditCircuit(units=old.model.C,motors=old.model.M,inputs=old.model.E,
        edges=old.edges,thresholds=old.thresholds,initial=old.initial,P=old.P,H=old.H,L=old.L,R=old.R)
    push!(rows,_catalog_row("p6-one-input-all-four","one_input_one_motor_P6_H6_L4_R4",
        old_circuit,ModelAudit.measure_circuit(old_circuit);origin="original_six_unit_fixture"))
    for stored in ModelAudit.measured_witness_corpus()["witnesses"]
        circuit = ModelAudit.parse_audit_circuit(stored["circuit"])
        push!(rows,_catalog_row("p6-dc-only-"*stored["name"],"one_input_two_motors_P6_H6_L4_R4",
            circuit,ModelAudit.measure_circuit(circuit);origin="fixed_sequence_search"))
    end
    dc2 = ModelAudit.dc2_witness_corpus()
    for ref in ModelAudit.lean_reference_m1r()
        push!(rows,_abstract_row("m1r-"*ref.name,"lean_reference_M1R",ref.model;origin="lean_reference_model"))
    end
    for w in dc2["abstract"]
        model = ModelAudit.dc2_carrier_model(w["encoding"];nC=w["nC"],nM=w["nM"],nE=w["nE"])
        push!(rows,_abstract_row("dc2-"*w["name"],"abstract_carrier_C$(w["nC"])_M$(w["nM"])_E$(w["nE"])",
            model;origin=w["selection"]))
    end
    # Measured DC2 witnesses come from the same one-input two-motor P6 search domains as the
    # p6-dc-only rows; a circuit already in the catalog is not added twice.
    for w in dc2["measured"]
        circuit = ModelAudit.parse_audit_circuit(w["circuit"])
        digest = ModelAudit._audit_digest(ModelAudit.circuit_dict(circuit))
        any(row->get(row,"circuit_digest","")==digest,rows) && continue
        push!(rows,_catalog_row("dc2-"*w["name"],"one_input_two_motors_P6_H6_L4_R4",
            circuit,ModelAudit.measure_circuit(circuit);origin="dc2_search_first_nondegenerate"))
    end
    length(unique(row["id"] for row in rows)) == length(rows) || error("duplicate catalog model ID")
    Dict("schema_version"=>1,"phenomenal_claim"=>"not_certified","execution_certified"=>false,
        "catalog_scope"=>"finite_recomputed_models","model_count"=>length(rows),"models"=>rows)
end

struct CountermodelQuery
    query_id::String
    contexts::Tuple{Vararg{String}}
    premises::Tuple{Vararg{Pair{Symbol,Bool}}}
    conclusion::Pair{Symbol,Bool}
    function CountermodelQuery(;query_id,contexts,premises,conclusion)
        id = ModelAudit._audit_text(query_id)
        cs = ModelAudit._audit_strings(contexts)
        isempty(cs) && throw(ArgumentError("at least one exact context is required"))
        ps = Tuple(_predicate_pair(p) for p in premises)
        length(unique(first.(ps))) == length(ps) || throw(ArgumentError("duplicate premise predicate"))
        goal = _predicate_pair(conclusion)
        first(goal) ∉ first.(ps) || throw(ArgumentError("conclusion repeats a premise"))
        new(id,cs,ps,goal)
    end
end

function _predicate_pair(value)
    value isa Pair || throw(ArgumentError("predicate condition must be a Pair"))
    key = value.first isa Symbol ? value.first : value.first isa AbstractString ? Symbol(value.first) :
        throw(ArgumentError("invalid predicate name"))
    key in QUERY_PREDICATES || throw(ArgumentError("unknown audit predicate"))
    value.second isa Bool || throw(ArgumentError("predicate expectation must be Boolean"))
    key=>value.second
end

function parse_countermodel_query(data::AbstractDict)
    ModelAudit._exact_keys(data,("schema_version","query_id","contexts","premises","conclusion"))
    typeof(data["schema_version"]) == Int && data["schema_version"] == 1 ||
        throw(ArgumentError("unsupported countermodel query schema"))
    data["premises"] isa AbstractDict && data["conclusion"] isa AbstractDict ||
        throw(ArgumentError("premises/conclusion must be tables"))
    length(data["conclusion"]) == 1 || throw(ArgumentError("exactly one conclusion is required"))
    CountermodelQuery(query_id=data["query_id"],contexts=data["contexts"],
        premises=Tuple(Symbol(k)=>v for (k,v) in data["premises"]),
        conclusion=only(Symbol(k)=>v for (k,v) in data["conclusion"]))
end

function query_countermodels(query::CountermodelQuery,catalog=finite_model_catalog())
    ModelAudit._exact_keys(catalog,("schema_version","phenomenal_claim","execution_certified","catalog_scope","model_count","models"))
    known_contexts = Set(row["context"] for row in catalog["models"])
    unknown_contexts = setdiff(Set(query.contexts),known_contexts)
    isempty(unknown_contexts) || throw(ArgumentError("query names contexts absent from the catalog"))
    context_rows = [row for row in catalog["models"] if row["context"] in query.contexts]
    eligible = Dict{String,Any}[]
    unknown = Dict{String,Any}[]
    for row in context_rows
        obs = row["observations"]
        missing_predicates = [String(key) for (key,_) in (query.premises... , query.conclusion) if !haskey(obs,String(key))]
        if !isempty(missing_predicates)
            push!(unknown,Dict("id"=>row["id"],"unknown_predicates"=>sort!(unique(missing_predicates))))
            continue
        end
        all(obs[String(key)] == value for (key,value) in query.premises) && push!(eligible,row)
    end
    key,expected = query.conclusion
    countermodels = [row for row in eligible if row["observations"][String(key)] != expected]
    (;query,context_model_count=length(context_rows),eligible_count=length(eligible),
       unknown=Tuple(unknown),countermodels=Tuple(countermodels),
       classification=isempty(countermodels) ? :not_found_in_finite_catalog : :counterexample_found,
       implication_proved=false,general_impossibility=:not_established,phenomenal_claim=:not_certified)
end

function countermodel_query_report(result)
    q = result.query
    Dict("schema_version"=>1,"query_id"=>q.query_id,"contexts"=>collect(q.contexts),
        "premises"=>Dict(String(k)=>v for (k,v) in q.premises),
        "conclusion"=>Dict(String(q.conclusion.first)=>q.conclusion.second),
        "classification"=>String(result.classification),"context_model_count"=>result.context_model_count,
        "eligible_count"=>result.eligible_count,"unknown_models"=>collect(result.unknown),
        "countermodels"=>collect(result.countermodels),"countermodel_count"=>length(result.countermodels),
        "implication_proved"=>false,"general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified","execution_certified"=>false)
end

end
