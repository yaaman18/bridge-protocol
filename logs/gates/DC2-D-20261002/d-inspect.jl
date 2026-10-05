using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
function inspect(domain, case)
    MA.for_each_search_circuit(domain, case + 1, 20260910) do c, id
        id == case || return
        m = MA.measure_circuit(c; all_interventions=false)
        d = MA.check_dc2(m.model); dv = MA.check_dc2(MA.motor_action_variant(m))
        g = MA.unit_organization(c)
        println("== $domain case $case  motors=", c.motors, " thresholds=", c.thresholds)
        println(" edges=", [(c.units[s], c.units[t], w) for (s, t, w) in c.edges])
        println(" κ=", sort!(collect(m.model.kappa)), " baseline=", sort!(collect(m.baseline)))
        for u in c.units
            println("  silence ", u, ": loss=", sort!(collect(m.losses[1 << (findfirst(==(u), c.units)-1)])),
                "  ρ=", sort!(collect(m.model.rho[u])), u in c.motors ? "  π=" * string(sort!(collect(m.model.pi[u]))) : "")
        end
        println(" N3 pairs=", d.mutual_pairs, " N3(D) pairs=", dv.mutual_pairs, " G3 cycles=", g.cycles)
    end
end
inspect(:four_unit_exhaustive, 5361)
inspect(:four_unit_exhaustive, 6459)
inspect(:six_unit_sequence, 94)
inspect(:six_unit_sequence, 1150)
