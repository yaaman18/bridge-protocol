# N3 against the mechanism-level ground truth (edge removal) on every circuit of the two declared
# search domains. Exploratory; changes no definition or default.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit

function all_actions_n3(c, m)
    loss(u) = m.losses[1 << (findfirst(==(u), c.units) - 1)]
    K = collect(m.model.kappa)
    prod(d, x) = any(a -> x in loss(a), loss(d))      # every unit an action: rho = pi = loss
    any(x != y && prod(y, x) && prod(x, y) for x in K, y in K)
end

for domain in (:four_unit_exhaustive, :six_unit_sequence), reading in (:weak, :strict)
    n = Dict{String,Int}()
    bump(k) = (n[k] = get(n, k, 0) + 1)
    examples = Dict{String,Int}()
    MA.for_each_search_circuit(domain, nothing, 20260910) do c, id
        m = MA.measure_circuit(c; all_interventions=false)
        d = MA.check_dc2(m.model)
        g = MA.mechanism_organization(c)
        G = reading == :weak ? g.G_weak : g.G_strict
        cycles = [Set(z) for z in (reading == :weak ? g.weak_cycles : g.strict_cycles)]
        groups = MA.cycle_components(cycles)
        for p in d.mutual_pairs
            any(z -> Set(p) ⊆ z, groups) || (bump("unsound_pair"); get!(examples, "unsound_pair", id))
        end
        if d.hUnit && G
            bump("true_positive")
        elseif !d.hUnit && !G
            bump("true_negative")
        elseif d.hUnit
            bump("false_positive"); get!(examples, "false_positive", id)
        else
            cause = if !any(z -> any(u -> u in c.motors, z), cycles)
                "fn_motorless_cycles"
            elseif all_actions_n3(c, m)
                "fn_fixed_when_all_units_are_actions"
            else
                full = MA.measure_circuit(c)
                joint = any(u -> any(mk -> count_ones(mk) >= 2, full.minima[u]), union(cycles...))
                # Known checker limitation: every carrying cycle shares an edge with another
                # excitatory cycle, so its removal also breaks that cycle (case 5490).
                idx(z) = [findfirst(==(u), c.units) for u in z]
                edges_of(z) = (v = idx(z); Set((v[i], v[mod1(i + 1, length(v))]) for i in eachindex(v)))
                pos = Tuple(e for e in c.edges if e[3] > 0)
                all_cycles = [Set(edges_of(c.units[z])) for z in MA._simple_cycles(Set(eachindex(c.units)), pos)]
                carrying = reading == :weak ? g.weak_cycles : g.strict_cycles
                shared = all(z -> any(o -> o != edges_of(z) && !isdisjoint(o, edges_of(z)), all_cycles), carrying)
                joint ? "fn_joint_silencing_dependence" : shared ? "fn_shared_edge_checker_limit" : "fn_unexplained"
            end
            bump(cause); get!(examples, cause, id)
        end
    end
    println(domain, " ", reading, " ", sort!(collect(n)), " first examples ", sort!(collect(examples)))
end
