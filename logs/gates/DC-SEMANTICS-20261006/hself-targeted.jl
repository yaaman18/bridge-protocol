# A targeted variant: keep the action-mediated reading for every core constituent, and use C only for
# constituents that are lost only under joint silencing (collective_only_loss):
#   hSelf_T ⟺ ∀ c ∈ κ, c ∈ Φ(κ) ∨ (c ∈ collective_only ∧ every minimal loss set of c meets κ ∪ ε)
# Exploratory.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 6000))
    R = Dict{String,Int}()
    bump(k) = (R[k] = get(R, k, 0) + 1)
    MA.for_each_search_circuit(domain, limit, 20260910) do c, id
        units = c.units
        m = MA.measure_circuit(c)
        kappa = m.model.kappa
        isempty(kappa) && return
        bump("cores")
        bit(u) = 1 << (findfirst(==(u), units) - 1)
        keep = foldl((acc, u) -> acc | bit(u), union(kappa, m.model.epsilon); init=0)
        phi = MA._dc2_phi(m.model.pi, m.model.rho, kappa)
        cmin(u) = !isempty(m.minima[u]) && all(a -> a & keep != 0, m.minima[u])
        hS = m.result.actual[1]
        hT = all(u -> u in phi || (u in m.collective && cmin(u)), kappa)
        hS && !hT && bump("ERROR_targeted_rejects_hSelf_pass")     # must never happen
        (!hS && hT) && bump("rescued_by_targeted")
        (!hS && !hT) && bump("still_false")
        hS && bump("hSelf_true")
    end
    println("== ", domain)
    for k in sort!(collect(keys(R)))
        println("  ", rpad(k, 38), R[k])
    end
end
