using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
function inspect(case)
    MA.for_each_search_circuit(:six_unit_sequence, case + 1, 20260910) do c, id
        id == case || return
        m = MA.measure_circuit(c; all_interventions=false)
        d = MA.check_dc2(m.model); g = MA.pair_organization(c)
        println("== six_unit_sequence case $case motors=", c.motors, " thresholds=", c.thresholds)
        println(" edges=", [(c.units[s], c.units[t], w) for (s, t, w) in c.edges])
        println(" κ=", sort!(collect(m.model.kappa)), " baseline=", sort!(collect(m.baseline)))
        for u in c.units
            println("  silence ", u, ": loss=", sort!(collect(m.losses[1 << (findfirst(==(u), c.units)-1)])))
        end
        println(" N3 pairs=", d.mutual_pairs, " v4 pairs=", g.pairs)
    end
end
foreach(inspect, (8032, 4862, 1600))
