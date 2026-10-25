# Trial (not adopted): the ablation of ValueNeeded restricted to value-tracking units outside the
# endogenous core. Compared against the frozen labels of all three template sets and on the random
# circuits of sweep-and-search.jl. The adopted criteria are unchanged.
using AgencySubstrate
const AS = AgencySubstrate
include(joinpath(@__DIR__, "sweep-and-search-generator.jl"))
base = load_templates()
function variant(s, setup)
    r = evaluate(s, setup)
    idx(nm) = findfirst(==(nm), s.names)
    core = Set(idx(x) for x in r.core)
    T2 = [idx(x) for x in r.value_tracking if !(idx(x) in core)]
    needed2 = !isempty(T2) && AS.value_needed(s, setup.params, setup.survival, T2)
    (; r, T2=[s.names[u] for u in T2],
       agency2=!isempty(r.core) && r.core_enables_action && r.alive_somewhere && r.differentiated && needed2)
end
fx = joinpath("tools", "AgencySubstrate", "fixtures")
for f in ("templates.toml", "templates-adversarial.toml", "templates-adversarial-2.toml")
    set = load_templates(joinpath(fx, f))
    for t in set.templates
        v = variant(t.substrate, set)
        println(rpad(f, 30), rpad(t.name, 24), " label L2=", t.L2, " adopted=", v.r.agency, " variant=", v.agency2,
                v.agency2 == t.L2 ? "" : "  <-- disagrees")
    end
end
state = Ref(UInt64(20261009))
n_adopted = 0; n_variant = 0; lost = Int[]; emptyT2 = 0
for k in 1:20000
    s = random_substrate(state)
    v = variant(s, base)
    v.r.agency && (global n_adopted += 1)
    v.agency2 && (global n_variant += 1)
    if v.r.agency && !v.agency2
        push!(lost, k); isempty(v.T2) && (global emptyT2 += 1)
    end
end
println("random: adopted=", n_adopted, " variant=", n_variant, " lost=", length(lost), " (tracking entirely inside core: ", emptyT2, ")")
state = Ref(UInt64(20261009)); shown = 0
for k in 1:20000
    s = random_substrate(state)
    (k in lost && shown < 3) || continue
    global shown += 1
    v = variant(s, base)
    println("#", k, " units=", s.names, " edges=", [(s.names[a], s.names[b], w) for (a, b, w) in s.edges])
    println("   core=", v.r.core, " tracking=", v.r.value_tracking, " outside-core=", v.T2,
            " survival=", v.r.survival, " without tracking=", v.r.survival_without_tracking)
end
