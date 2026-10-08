# A concrete failure of transitivity of single-unit necessity in the all-positive-weight domain.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
const FOUND = Ref(0)
MA.for_each_search_circuit(:four_unit_exhaustive, nothing, 20260910) do c, id
    FOUND[] >= 2 && return
    units = c.units
    m = MA.measure_circuit(c; all_interventions=false)
    L(u) = m.losses[1 << (findfirst(==(u), units) - 1)]
    for y in units, a in units, x in units
        (a in L(y) && x in L(a) && !(x in L(y))) || continue
        FOUND[] += 1
        println("== case ", id, "  (all weights +1)")
        println(" edges=", [(units[s], units[t], w) for (s, t, w) in c.edges],
                " thresholds=", c.thresholds, " initial=", Int.(collect(c.initial)))
        println(" baseline=", sort!(collect(m.baseline)), " κ=", sort!(collect(m.model.kappa)))
        for u in units
            println("   silence ", u, ": loss=", sort!(collect(L(u))))
        end
        println(" y=", y, " a=", a, " x=", x,
                ": a∈L(y)=", a in L(y), " x∈L(a)=", x in L(a), " x∈L(y)=", x in L(y))
        break
    end
end
