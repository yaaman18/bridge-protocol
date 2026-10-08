# Properties of the candidate closure C, and the conditional form of the degeneracy claim.
# Exploratory. Two readings of C:
#   C_min(Y) = {c : every inclusion-minimal loss set of c meets Y ∪ ε}
#   C_dir(Y) = {c : c persists when everything outside Y ∪ ε is silenced}
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
const R = Dict{String,Int}()
bump(k, v=1) = (R[k] = get(R, k, 0) + v)

for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 6000))
    empty!(R)
    MA.for_each_search_circuit(domain, limit, 20260910) do c, id
        units, n = c.units, length(c.units)
        m = MA.measure_circuit(c)
        full = (1 << n) - 1
        bit(u) = 1 << (findfirst(==(u), units) - 1)
        L(mask) = m.losses[mask]
        kappa, eps, motors = m.model.kappa, m.model.epsilon, Set(c.motors)
        eps_mask = foldl((acc, u) -> acc | bit(u), eps; init=0)
        mask_of(Y) = foldl((acc, u) -> acc | bit(u), Y; init=0)
        C_min(Y) = Set(u for u in units if !isempty(m.minima[u]) &&
                       all(a -> a & (mask_of(Y) | eps_mask) != 0, m.minima[u]))
        C_dir(Y) = Set(u for u in units if u in m.baseline && u ∉ L(full & ~(mask_of(Y) | eps_mask)))
        core = sort!(collect(kappa))
        subsets = [Set(core[i] for i in eachindex(core) if (v >> (i - 1)) & 1 == 1)
                   for v in 0:((1 << length(core)) - 1)]
        # (f) the degeneracy claim in its conditional form, under the CURRENT Phi2
        Cu = collect(units)
        post2(Y) = MA._dc2_postfixed(Cu, m.model.pi, m.model.rho, Y)
        if !isempty(kappa) && post2(kappa)
            bump("core_postfixed")
            any(u -> post2(Set([u])), kappa) && bump("core_postfixed_with_singleton")
            # is that singleton explained by c ∈ L(c)?
            any(u -> post2(Set([u])) && u in L(bit(u)), kappa) && bump("singleton_with_self_loss")
        end
        # (g) monotonicity of each reading
        for Y in subsets, Z in subsets
            Y ⊆ Z || continue
            C_min(Y) ⊆ C_min(Z) || bump("C_min_nonmonotone")
            C_dir(Y) ⊆ C_dir(Z) || bump("C_dir_nonmonotone")
        end
        # (h) redundancy: units lost only under joint silencing
        for u in m.collective
            bump("collective_only_units")
            u in C_min(kappa) && bump("collective_in_C_min")
            any(a -> a in motors && a in intersect(L(bit(u)), motors) && u in L(bit(a)), units) &&
                bump("collective_in_Phi")
        end
        # (i) naive C (no ε) vs ε-relativized C on the core, and hAct
        naive = Set(u for u in units if u in m.baseline && u ∉ L(full & ~mask_of(kappa)))
        isempty(kappa) && return
        bump("cores")
        kappa ⊆ naive && bump("core_postfixed_naive_C")
        kappa ⊆ C_dir(kappa) && bump("core_postfixed_eps_C")
        isempty(MA.check_dc2(m.model).act) || bump("act_nonempty")
        (kappa ⊆ naive && isempty(MA.check_dc2(m.model).act)) && bump("naive_C_without_hinge")
    end
    println("== ", domain)
    for k in sort!(collect(keys(R)))
        println("  ", rpad(k, 34), R[k])
    end
end
