using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
function inspect(domain, case)
    MA.for_each_search_circuit(domain, case + 1, 20260910) do c, id
        id == case || return
        m = MA.measure_circuit(c; all_interventions=false)
        d = MA.check_dc2(m.model)
        o = MA.mechanism_organization(c)
        println("== $domain case $case")
        println(" motors=", c.motors, " thresholds=", c.thresholds, " initial=", Int.(collect(c.initial)))
        println(" edges=", [(c.units[s], c.units[t], w) for (s, t, w) in c.edges])
        println(" κ=", sort!(collect(m.model.kappa)), " baseline=", sort!(collect(m.baseline)), " anchor=", Int.(collect(m.anchor)))
        for u in c.units
            println("  silence ", u, ": loss=", sort!(collect(m.losses[1 << (findfirst(==(u), c.units)-1)])))
        end
        println(" N3 pairs=", d.mutual_pairs, " org=", o.organization_cycles, " baseline=", o.baseline)
    end
end
for (d, c) in ((:four_unit_exhaustive, 5361), (:six_unit_sequence, 122))
    inspect(d, c)
end
