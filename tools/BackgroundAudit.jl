isdefined(@__MODULE__, :ModelAudit) || include("ModelAudit.jl")

module BackgroundAudit

import ..ModelAudit
using ERIEC

function check_adjunction_background(model)
    ModelAudit._finite_encoding_valid(model) || throw(ArgumentError("invalid finite model encoding"))
    length(model.M) + length(model.E) <= 10 || throw(ArgumentError("adjunction audit limited to 10 role units"))
    alpha = m -> copy(model.alpha[m])
    sigma = e -> copy(model.sigma[e])
    counterexample = nothing
    checked_pairs = 0
    for N in ERIEC.powerset(model.M), X in ERIEC.powerset(model.E)
        lhs = ERIEC.alpha_star(alpha,N) ⊆ X
        rhs = N ⊆ ERIEC.sigma_star(sigma,X)
        checked_pairs += 1
        if lhs != rhs && counterexample === nothing
            counterexample = (N=copy(N), X=copy(X), lhs=lhs, rhs=rhs)
        end
    end
    holds = counterexample === nothing
    checker = ERIEC.check_galois_conn(alpha,sigma,model.M,ERIEC.powerset(model.E))
    holds == checker || error("adjunction audit disagrees with the existing checker")
    (; holds, counterexample, checked_pairs, checker_matched=true, phenomenal_claim=:not_certified)
end

function relative_abstract_models()
    base = ModelAudit.abstract_dc_models()[1].model
    no_self = deepcopy(base)
    empty!(no_self.pi[:m1])
    # M2 permits environmental elements outside the image of alpha. Epsilon can include one.
    no_smc = merge(deepcopy(base),(E=(:e1,:e2,:e3),C=(base.C...,:e3),epsilon=Set([:e1,:e3])))
    no_smc.sigma[:e3] = Set{Symbol}()
    no_smc.rho[:e3] = Set{Symbol}()
    no_smc.neighbors[:e3] = Set{Symbol}()
    # The two sides of Act may inhabit disjoint motor fibers while alpha/sigma remain adjoint.
    no_act = merge(deepcopy(base),(epsilon=Set([:e2]),))
    no_bound = deepcopy(base)
    empty!(no_bound.neighbors[:c1])
    models = (base,no_self,no_smc,no_act,no_bound)
    [(name=ModelAudit._pattern_name(p),model=model,expected=p)
        for (model,p) in zip(models,ModelAudit.AUDIT_TARGET_PATTERNS)]
end

function _background_row(name,origin,model,expected=nothing)
    dc = ModelAudit.check_dc_pattern(model,expected === nothing ? (true,true,true,true) : expected)
    background = check_adjunction_background(model)
    data = Dict{String,Any}("name" => name,"origin" => origin,"model" => ModelAudit._model_dict(model),
        "dc_actual" => collect(dc.actual),"nondegenerate" => dc.nondegenerate,
        "adjunction_holds" => background.holds,"checked_subset_pairs" => background.checked_pairs,
        "background" => "finite_relational_galois_connection", "phenomenal_claim" => "not_certified")
    if expected !== nothing
        data["expected"] = collect(expected)
        data["relative_pattern_matched"] = dc.valid && dc.matches && background.holds
    end
    if background.counterexample !== nothing
        ce = background.counterexample
        data["counterexample"] = Dict("N" => ModelAudit._audit_names(ce.N),"X" => ModelAudit._audit_names(ce.X),
            "alpha_N_subset_X" => ce.lhs,"N_subset_sigma_X" => ce.rhs)
    end
    data
end

function background_audit_report()
    rows = [_background_row(ex.name,"abstract_with_adjunction",ex.model,ex.expected) for ex in relative_abstract_models()]
    all(row["relative_pattern_matched"] for row in rows) || error("relative abstract witness failed")
    old = ModelAudit.measured_dc_model()
    push!(rows,_background_row("original_six_unit_witness","measured_source_silencing",old.model))
    for row in ModelAudit.measured_witness_corpus()["witnesses"]
        measured = ModelAudit.measure_circuit(ModelAudit.parse_audit_circuit(row["circuit"]))
        push!(rows,_background_row(row["name"],"measured_separation_corpus",measured.model))
    end
    Dict("schema_version" => 1,"phenomenal_claim" => "not_certified","execution_certified" => false,
        "dc_definition_changed" => false,"full_M1_M4" => "not_established",
        "predicate_order" => String.(collect(ModelAudit.DC_FIELDS)),"models" => rows)
end

include("background_audit/MeasuredWitnesses.jl")

end
