# The joint counts of "endogenous core nonempty" and L3 over the random circuits of sweep-and-search.jl.
using AgencySubstrate
const AS = AgencySubstrate
include(joinpath(@__DIR__, "sweep-and-search-generator.jl"))
base = load_templates()
state = Ref(UInt64(20261009))
n = Dict((a, b) => 0 for a in (true, false), b in (true, false))
for k in 1:20000
    s = random_substrate(state)
    core = !isempty(AS.endogenous_core(s, base.choice_params, base.survival[1]))
    l3 = AS.self_producing(s, base.params, base.choice_params, base.survival)
    n[(core, l3)] += 1
end
println("core nonempty & L3 = ", n[(true, true)], "; core nonempty & not L3 = ", n[(true, false)],
        "; core empty & L3 = ", n[(false, true)], "; neither = ", n[(false, false)])
