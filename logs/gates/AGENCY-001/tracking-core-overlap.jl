# Among the random circuits that pass agency, how often the value-tracking set overlaps the core, and
# whether agency still holds when the ablation is restricted to tracking units outside the core.
using AgencySubstrate
const AS = AgencySubstrate
include(joinpath(@__DIR__, "sweep-and-search-generator.jl"))
base = load_templates()
state = Ref(UInt64(20261009))
pass = 0; overlap = 0; still = 0
for k in 1:20000
    s = random_substrate(state)
    r = evaluate(s, base)
    r.agency || continue
    global pass += 1
    idx(nm) = findfirst(==(nm), s.names)
    T = [idx(x) for x in r.value_tracking]; core = Set(idx(x) for x in r.core)
    if any(in(core), T)
        global overlap += 1
        T2 = [u for u in T if !(u in core)]
        AS.value_needed(s, base.params, base.survival, T2) && (global still += 1)
    end
end
println("agency passers=", pass, "  tracking overlaps core=", overlap, "  of which agency still holds with tracking outside the core only=", still)
for t in vcat(load_templates().templates, load_templates(joinpath("tools","AgencySubstrate","fixtures","templates-adversarial-2.toml")).templates)
    r = evaluate(t.substrate, base)
    r.agency && println(rpad(t.name, 24), " tracking=", r.value_tracking, " core=", r.core)
end
