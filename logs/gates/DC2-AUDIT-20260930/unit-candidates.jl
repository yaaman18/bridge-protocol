using ERIEC
include("/Users/yamaguchimitsuyuki/bridge-protocol/tools/ModelAudit.jl")
const MA = ModelAudit
# Candidate replacements of hUnit (∃ U ⊆ κ, IrredUnit U ∧ NonSingleton U).
#  N0 current;  N1 NonSingleton dropped (any irreducible unit);
#  N2 mutual unit: ∃ U ⊆ κ, |U| ≥ 2, PostFixed2 U, ∀ c ≠ d ∈ U, c ∈ Phi2({d});
#  N3 mutual pair: ∃ c ≠ d ∈ κ, c ∈ Phi2({d}) ∧ d ∈ Phi2({c}) (N2 restricted to pairs, no PostFixed2)
function units(m)
    C = collect(m.C); K = sort!(collect(Set{Symbol}(m.kappa))); k = length(K)
    post(Y) = MA._dc2_postfixed(C, m.pi, m.rho, Y)
    phi2(Y) = intersect(MA._dc2_phi(m.pi, m.rho, Y), MA._dc2_psi(C, m.pi, m.rho, Y))
    P = Dict(d => phi2(Set([d])) for d in K)
    ps = [post(MA._dc2_subset(K, v)) for v in 0:((1 << k) - 1)]
    irr(v) = ps[v+1] && (s = (v-1) & v; ok = true; while s != 0; ps[s+1] && (ok = false; break); s = (s-1) & v; end; ok)
    n1 = any(v -> irr(v), 1:((1 << k) - 1))
    n0 = any(v -> count_ones(v) >= 2 && irr(v), 1:((1 << k) - 1))
    n2 = any(1:((1 << k) - 1)) do v
        count_ones(v) >= 2 && ps[v+1] || return false
        U = MA._dc2_subset(K, v)
        all(c == d || c in P[d] for c in U, d in U)
    end
    n3 = any(c != d && c in P[d] && d in P[c] for c in K, d in K)
    (N0=n0, N1=n1, N2=n2, N3=n3)
end
const NAMES = (:N0, :N1, :N2, :N3)
function tally!(acc, m)
    d = MA.check_dc2(m); d.valid || return
    u = units(m); nd = MA.dc2_nondegenerate(m)
    for n in NAMES
        v = (d.hSelf2, d.hSMC, d.hHingeNeeded, getproperty(u, n))
        i = findfirst(p -> p.values == v, MA.DC2_PATTERNS)
        i === nothing && continue
        key = (n, MA.DC2_PATTERNS[i].name, nd ? "nondeg" : "any")
        acc[key] = get(acc, key, 0) + 1
    end
    # unit predicate true/false among hSelf2 ∧ κ ≠ ∅ (is it just a restatement of hSelf2?)
    if d.hSelf2 && !isempty(m.kappa)
        for n in NAMES; acc[(n, "unit_false_given_postfixed_core", "any")] = get(acc, (n, "unit_false_given_postfixed_core", "any"), 0) + !getproperty(u, n); end
    end
end
show_acc(title, acc) = begin
    println("== ", title)
    for n in NAMES
        row = [string(p.name, "=", get(acc, (n, p.name, "nondeg"), 0)) for p in MA.DC2_PATTERNS]
        println("  ", n, " nondeg: ", join(row, " "), " | unit false though core postfixed: ", get(acc, (n, "unit_false_given_postfixed_core", "any"), 0))
    end
end
println("Lean refs:")
for r in MA.lean_reference_m1r()
    println("  ", r.name, " ", units(r.model), " hSelf2=", MA.check_dc2(r.model).hSelf2, " HN=", MA.check_dc2(r.model).hHingeNeeded)
end
acc = Dict{Any,Int}()
for bits in 0:((1 << 20) - 1); tally!(acc, MA.dc2_carrier_model(bits)); end
show_acc("C3 M2 E1 exhaustive", acc)
acc = Dict{Any,Int}()
state = UInt64(20260930)
for _ in 1:1_000_000
    global state = state * UInt64(6364136223846793005) + UInt64(1442695040888963407)
    tally!(acc, MA.dc2_carrier_model(Int((state >> 11) & ((UInt64(1) << 25) - 1)); nC=4))
end
show_acc("C4 M2 E1 sample 1e6", acc)
for domain in (:four_unit_exhaustive, :six_unit_sequence)
    acc = Dict{Any,Int}()
    MA.for_each_search_circuit(domain, nothing, 20260910) do c, id
        tally!(acc, MA.measure_circuit(c; all_interventions=false).model)
    end
    show_acc("measured $domain", acc)
end
