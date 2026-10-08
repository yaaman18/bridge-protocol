# How the RSB-PLAN-002 §5.3 classification moves when the hSelf part uses hSelf_T instead of mask_self.
# Audit domains only (the registered profile is not measured). Exploratory.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 6000))
    R = Dict{String,Int}()
    bump(k) = (R[k] = get(R, k, 0) + 1)
    MA.for_each_search_circuit(domain, limit, 20260910) do c, id
        units, n = c.units, length(c.units)
        m = MA.measure_circuit(c)
        hSelf, hSMC, hAct, hBound = m.result.actual
        motors, inputs = Set(c.motors), Set(c.inputs)
        kappa = m.model.kappa
        bit(u) = 1 << (findfirst(==(u), units) - 1)
        # collective_only_change: final state changes under some multi-silencing, never under a single one
        base = last(m.traces[0])
        changed(mask) = Set(units[i] for i in 1:n if last(m.traces[mask])[i] != base[i])
        single = union((changed(1 << (i - 1)) for i in 1:n)...)
        anyc = union((changed(mk) for mk in 1:((1 << n) - 1))...)
        cchange = setdiff(anyc, single)
        coll = m.collective
        mask_self = !isempty(intersect(coll, kappa)) || !isempty(intersect(coll, motors))
        mask_smc = !isempty(intersect(cchange, union(inputs, motors)))
        mask_act = !isempty(intersect(coll, motors)) || !isempty(intersect(cchange, motors))
        keep = foldl((acc, u) -> acc | bit(u), union(kappa, m.model.epsilon); init=0)
        phi = MA._dc2_phi(m.model.pi, m.model.rho, kappa)
        cmin(u) = !isempty(m.minima[u]) && all(a -> a & keep != 0, m.minima[u])
        hSelf_T = all(u -> u in phi || (u in coll && cmin(u)), kappa)
        dc = hSelf && hSMC && hAct && hBound
        dc && (bump("pass"); return)
        bump("dc_false")
        old = hBound && (hSelf || mask_self) && (hSMC || mask_smc) && (hAct || mask_act)
        new = hBound && (hSelf || hSelf_T) && (hSMC || mask_smc) && (hAct || mask_act)
        old && bump("ambiguous_old_mask_self")
        new && bump("ambiguous_new_hSelf_T")
        (old && !new) && bump("old_only")
        (new && !old) && bump("new_only")
        # DC with redundancy-credited hSelf (a sensitivity reading, not a certification)
        (hSelf_T && hSMC && hAct && hBound) && bump("dc_T_true_among_dc_false")
    end
    df = R["dc_false"]
    println("== ", domain, "  pass=", get(R, "pass", 0), "  dc_false=", df)
    for k in ("ambiguous_old_mask_self", "ambiguous_new_hSelf_T", "old_only", "new_only", "dc_T_true_among_dc_false")
        v = get(R, k, 0)
        println("  ", rpad(k, 30), v, "  (", round(100v / df; digits=1), "% of dc_false)")
    end
end
