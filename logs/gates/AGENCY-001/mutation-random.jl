# For the two mutants that survive the frozen templates: on the random circuits, how many verdicts change.
using AgencySubstrate
const AS = AgencySubstrate
include(joinpath(@__DIR__, "sweep-and-search-generator.jl"))
base = load_templates()
mut = get(ARGS, 1, "none")
if mut == "no-domination-clause"
    @eval AS.value_needed(s, p, survival, T) = (isempty(T) && return false;
        any(x -> AS.survives(s, p, x) && !AS.survives(s, p, x; silenced=Set(T)), survival))
elseif mut == "core-without-silencing-sensors"
    @eval AS.endogenous_core(s, pc, schedule) = (traj = AS.run_trajectory(s, pc, schedule);
        tail = traj[(end - pc.alive_window + 1):end];
        all(st -> any(u -> st.active[u] && !AS.is_sensor(s, u), 1:AS.nunits(s)), tail) || return Int[];
        sort!(unique(u for st in tail for u in 1:AS.nunits(s) if st.active[u] && !AS.is_sensor(s, u))))
end
sr = only(t for t in load_templates(joinpath(@__DIR__, "..", "..", "..", "tools", "AgencySubstrate", "fixtures", "templates-adversarial.toml")).templates if t.name == "stimulus-response")
r = evaluate(sr.substrate, base)
println(mut, ": stimulus-response core=", r.core, " hinge=", r.core_enables_action, " differentiated=", r.differentiated, " value_needed=", r.value_needed, " agency=", r.agency)
state = Ref(UInt64(20261009)); n = 0
for k in 1:20000
    evaluate(random_substrate(state), base).agency && (global n += 1)
end
println(mut, ": random agency=", n)
