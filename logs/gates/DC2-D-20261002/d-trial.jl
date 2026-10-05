# Trial of reading (D) against the v3 truth (unit-level organization cycles) on both search domains.
# Exploratory: the default reading is unchanged.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit

for domain in (:four_unit_exhaustive, :six_unit_sequence)
    tally = Dict{String,Int}(); ex = Dict{String,Vector{Int}}()
    note(k, id) = (tally[k] = get(tally, k, 0) + 1; length(get!(ex, k, Int[])) < 3 && push!(ex[k], id))
    MA.for_each_search_circuit(domain, nothing, 20260910) do c, id
        measured = MA.measure_circuit(c; all_interventions=false)
        g = MA.unit_organization(c)
        groups = MA.cycle_components([Set(z) for z in g.cycles])
        for (label, model) in (("current", measured.model), ("D", MA.motor_action_variant(measured)),
                               ("D+self", MA.motor_self_production_variant(measured)))
            d = MA.check_dc2(model)
            note(label * ":" * (d.hUnit == g.G ? (d.hUnit ? "TP" : "TN") : d.hUnit ? "FP" : "FN"), id)
            any(p -> !any(gr -> Set(p) ⊆ gr, groups), d.mutual_pairs) && note(label * ":unsound_pair_circuit", id)
        end
        a = MA.check_dc2(measured.model)
        for (label, v) in (("D", MA.motor_action_variant(measured)), ("D+self", MA.motor_self_production_variant(measured)))
            b = MA.check_dc2(v)
            for k in (:dc2, :hSelf2, :hHingeNeeded, :hUnit, :beta_nonempty)
                getproperty(a, k) != getproperty(b, k) && note(label * " changed:" * String(k) * ":" * (getproperty(b, k) ? "to_true" : "to_false"), id)
            end
            a.act != b.act && note(label * " changed:act", id)
        end
    end
    println("== ", domain)
    for k in sort!(collect(keys(tally)))
        println("  ", rpad(k, 40), tally[k], "  e.g. ", ex[k])
    end
end
