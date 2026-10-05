# DC2 core (moved here from tools/model_audit/DC2.jl by RSB-003, 2026-10-04, without change of
# behaviour). The criterion package binds this file by its directory tree; the finite-model audit
# includes the same file, so the audited code and the bound code are one file.
#
# DC2 on finite relational models (formal-experiments/M1Refinement.lean, not ratified).
#
# Each definition below transcribes one Lean declaration of `ERIEC.M1R`, in the same order:
# Psi, Phi2, PostFixed2 (§3.1), IrredUnit, NonSingleton, MutualPair (§3.2), beta (§3.3),
# rhoNH, HingeNeeded (§3.4), DC2 (§3.5). Since 2026-09-30 DC2.hUnit is MutualPair
# (specs/packets/DC2-HUNIT-N3.md); the former IrredUnit ∧ NonSingleton is kept as `hUnit_v1`. DC2 is an experiment: this file records it for audit and
# for the analysis plan; it is not a certified checker and does not touch `ERIEC.DC`.
#
# The carriers M, E, C need not overlap (the Lean models use three separate types); measured
# models have M ⊆ C and E ⊆ C, which is also allowed. Relations are Dicts of Sets:
# alpha : M → Set E, sigma : E → Set M, pi : M → Set C, rho : C → Set M.

const DC2_MAX_CORE = 16

function _dc2_encoding_valid(model)
    M, E, C = Set(model.M), Set(model.E), Set(model.C)
    all(!isempty, (M, E, C)) || return false
    for (relation, domain, codomain) in ((model.alpha, M, E), (model.sigma, E, M),
                                        (model.pi, M, C), (model.rho, C, M))
        Set(keys(relation)) == domain || return false
        all(Set(image) ⊆ codomain for image in values(relation)) || return false
    end
    Set(model.kappa) ⊆ C && Set(model.epsilon) ⊆ E && length(model.kappa) <= DC2_MAX_CORE
end

_dc2_star(rel, xs) = foldl((acc, x) -> union!(acc, rel[x]), xs; init=Set{Symbol}())

# §3.1  Phi Y = pi*(rho* Y)            (ERIEC.Closure.Phi)
_dc2_phi(pi, rho, Y) = _dc2_star(pi, _dc2_star(rho, Y))
# §3.1  Psi Y = {c | ∃ a ∈ rho c, (pi a ∩ Y) nonempty}
_dc2_psi(C, pi, rho, Y) = Set(c for c in C if any(a -> !isdisjoint(pi[a], Y), rho[c]))
# §3.1  PostFixed2 K = K ⊆ Phi K ∩ Psi K
_dc2_postfixed(C, pi, rho, K) = K ⊆ intersect(_dc2_phi(pi, rho, K), _dc2_psi(C, pi, rho, K))

_dc2_subset(items, mask) = Set(items[i] for i in eachindex(items) if (mask >> (i - 1)) & 1 == 1)

"""
    check_dc2(model) -> NamedTuple

Evaluate DC2 and its parts on a finite model. `valid = false` means the encoding is not a model
(the other fields are then not computed). `mutual_pairs` lists the pairs of the core that produce
each other (MutualPair, the current hUnit); `irreducible_units` lists every non-singleton
irreducible unit inside the core (the former hUnit, reported as `hUnit_v1`).
"""
function check_dc2(model)
    _dc2_encoding_valid(model) || return (valid=false,)
    C = collect(model.C)
    K = Set{Symbol}(model.kappa)
    eps = Set{Symbol}(model.epsilon)
    items = sort!(collect(K))
    k = length(items)
    # PostFixed2 of every subset of the core (bit i ↔ items[i]).
    post = [_dc2_postfixed(C, model.pi, model.rho, _dc2_subset(items, v)) for v in 0:((1 << k) - 1)]
    hSelf2 = post[end]                                   # the whole core
    # §3.5 hSMC: eps ⊆ alpha*(sigma* eps)
    hSMC = eps ⊆ _dc2_star(model.alpha, _dc2_star(model.sigma, eps))
    # Hinge.Act = rho*(K) ∩ sigma*(eps)
    act = intersect(_dc2_star(model.rho, K), _dc2_star(model.sigma, eps))
    # §3.4 rhoNH: every relation with the hinge actions removed
    rhoNH = Dict(c => setdiff(model.rho[c], act) for c in C)
    # §3.4 HingeNeeded: no nonempty part of the core is PostFixed2 under rhoNH
    hHingeNeeded = !any(v -> _dc2_postfixed(C, model.pi, rhoNH, _dc2_subset(items, v)), 1:((1 << k) - 1))
    # §3.2 IrredUnit: nonempty, PostFixed2, and no proper nonempty PostFixed2 subset
    units = Vector{Vector{Symbol}}()
    for v in 1:((1 << k) - 1)
        post[v + 1] || continue
        proper_post = false
        sub = (v - 1) & v
        while sub != 0
            if post[sub + 1]
                proper_post = true
                break
            end
            sub = (sub - 1) & v
        end
        proper_post && continue
        count_ones(v) >= 2 && push!(units, sort!(collect(_dc2_subset(items, v))))   # §3.2 NonSingleton
    end
    hUnit_v1 = !isempty(units)
    # §3.2 MutualPair: c ≠ d in the core with c ∈ Phi({d}) and d ∈ Phi({c})
    produced = Dict(d => _dc2_phi(model.pi, model.rho, Set([d])) for d in items)
    pairs = [[c, d] for (i, c) in enumerate(items) for d in items[(i + 1):end]
             if c in produced[d] && d in produced[c]]
    hUnit = !isempty(pairs)
    # §3.3 beta = K ∩ pi*(Act)
    beta = intersect(K, _dc2_star(model.pi, act))
    (; valid=true, hSelf2, hSMC, hHingeNeeded, hUnit,
       dc2=hSelf2 && hSMC && hHingeNeeded && hUnit,
       act, beta, beta_nonempty=!isempty(beta),
       sigma_cover=_dc2_star(model.rho, K) ⊆ _dc2_star(model.sigma, eps),
       mutual_pairs=pairs, hUnit_v1, irreducible_units=units, phenomenal_claim=:not_certified)
end
