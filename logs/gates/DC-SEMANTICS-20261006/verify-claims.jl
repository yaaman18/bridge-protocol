# Verification of the claims about DC's semantics (2026-10-06). Exploratory: no definition,
# default or registered file is changed. The registered 8-unit profile is NOT measured.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit

# Every claim is checked on the two declared audit domains. four_unit_exhaustive has only +1
# weights (Search.jl); six_unit_sequence draws weights from {-1, 0, +1}.
for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 6000))
    n_circ = 0
    comp_fail = 0            # necessity is not transitive: a ∈ L(y), x ∈ L(a), x ∉ L(y)
    comp_fail_circ = 0
    self_loss = 0            # c ∈ L(c) among persisting c
    self_loss_tot = 0
    phi_self = 0             # c ∈ Phi({c}) among core c
    phi_self_tot = 0
    nonmono = 0              # loss not monotone in the silencing set
    nonmono_circ = 0
    cmin_ne_cdir = 0         # C read from minimal loss sets vs read directly
    singleton_only = 0       # every inclusion-minimal post-fixed set under Phi_C is a singleton
    multi_unit = 0
    post_any = 0
    MA.for_each_search_circuit(domain, limit, 20260910) do c, id
        n_circ += 1
        units, n = c.units, length(c.units)
        m = MA.measure_circuit(c)                       # all 2^n silencing sets
        full = (1 << n) - 1
        idx(u) = findfirst(==(u), units)
        bit(u) = 1 << (idx(u) - 1)
        L(mask) = m.losses[mask]
        single(u) = L(bit(u))
        kappa = m.model.kappa
        eps = m.model.epsilon
        motors = Set(c.motors)
        # (a) transitivity of single-unit necessity
        local bad = false
        for y in units, a in units, x in units
            (a in single(y) && x in single(a) && !(x in single(y))) && (comp_fail += 1; bad = true)
        end
        bad && (comp_fail_circ += 1)
        # (b) c ∈ L(c) and c ∈ Phi({c})
        for u in m.baseline
            self_loss_tot += 1
            u in single(u) && (self_loss += 1)
        end
        for u in kappa
            phi_self_tot += 1
            any(a -> a in motors && a in single(u) && u in single(a), units) && (phi_self += 1)
        end
        # (c) monotonicity of loss in the silencing set
        local nm = false
        for mask in 0:full, i in 0:(n - 1)
            (mask >> i) & 1 == 1 && continue
            bigger = mask | (1 << i)
            if !(L(mask) ⊆ L(bigger))
                nonmono += 1; nm = true
            end
        end
        nm && (nonmono_circ += 1)
        # (d) candidate C: minimal-loss-set reading vs direct reading
        eps_mask = foldl((acc, u) -> acc | bit(u), eps; init=0)
        core = sort!(collect(kappa))
        for v in 0:((1 << length(core)) - 1)
            Y = Set(core[i] for i in eachindex(core) if (v >> (i - 1)) & 1 == 1)
            ymask = foldl((acc, u) -> acc | bit(u), Y; init=0)
            keep = ymask | eps_mask
            silenced = full & ~keep
            direct = Set(u for u in units if u ∉ L(silenced) && u in m.baseline)
            minread = Set(u for u in units
                          if !isempty(m.minima[u]) && all(a -> a & keep != 0, m.minima[u]))
            direct == minread || (cmin_ne_cdir += 1)
        end
        # (e) under Phi_C^eps, are the inclusion-minimal post-fixed subsets of κ all singletons?
        k = length(core)
        post = falses(1 << k)
        for v in 1:((1 << k) - 1)
            Y = Set(core[i] for i in eachindex(core) if (v >> (i - 1)) & 1 == 1)
            keep = foldl((acc, u) -> acc | bit(u), Y; init=0) | eps_mask
            kept = Set(u for u in units if u ∉ L(full & ~keep) && u in m.baseline)
            post[v + 1] = Y ⊆ kept
        end
        mins = Int[]
        for v in 1:((1 << k) - 1)
            post[v + 1] || continue
            sub = (v - 1) & v
            proper = false
            while sub != 0
                post[sub + 1] && (proper = true; break)
                sub = (sub - 1) & v
            end
            proper || push!(mins, v)
        end
        if !isempty(mins)
            post_any += 1
            any(v -> count_ones(v) >= 2, mins) ? (multi_unit += 1) : (singleton_only += 1)
        end
    end
    println("== ", domain, "  circuits=", n_circ)
    println("  (a) necessity not transitive: ", comp_fail, " triples in ", comp_fail_circ, " circuits")
    println("  (b) c in L(c): ", self_loss, "/", self_loss_tot,
            "   c in Phi({c}) for core c: ", phi_self, "/", phi_self_tot)
    println("  (c) loss not monotone: ", nonmono, " pairs in ", nonmono_circ, " circuits")
    println("  (d) C from minimal sets != C read directly: ", cmin_ne_cdir, " subsets")
    println("  (e) circuits with a post-fixed set under Phi_C: ", post_any,
            "  singleton-only ", singleton_only, "  with a multi-unit minimal ", multi_unit)
end
