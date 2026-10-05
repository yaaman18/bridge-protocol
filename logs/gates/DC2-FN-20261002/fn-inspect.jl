using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
function inspect(domain, case)
    MA.for_each_search_circuit(domain, case + 1, 20260910) do c, id
        id == case || return
        m = MA.measure_circuit(c; all_interventions=false)
        d = MA.check_dc2(m.model)
        g = MA.mechanism_organization(c)
        println("== $domain case $case")
        println(" units=", c.units, " motors=", c.motors, " thresholds=", c.thresholds, " initial=", c.initial)
        println(" edges=", [(c.units[s], c.units[t], w) for (s, t, w) in c.edges])
        println(" κ=", sort!(collect(m.model.kappa)), " baseline=", sort!(collect(m.baseline)))
        println(" anchor=", m.anchor, " trace0=", [Int.(collect(x)) for x in m.traces[0]])
        for u in c.units
            println("  silence ", u, ": loss=", sort!(collect(m.losses[1 << (findfirst(==(u), c.units)-1)])))
        end
        println(" N3=", d.hUnit, " pairs=", d.mutual_pairs, " weak=", g.weak_cycles, " strict=", g.strict_cycles)
    end
end
inspect(:six_unit_sequence, 2564)
