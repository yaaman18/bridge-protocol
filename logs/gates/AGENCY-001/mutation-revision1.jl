# Mutation test: each mutant of the criteria must break agreement with the frozen labels somewhere.
using AgencySubstrate
const AS = AgencySubstrate
fx = joinpath(@__DIR__, "..", "..", "..", "tools", "AgencySubstrate", "fixtures")
sets = [load_templates(joinpath(fx, f)) for f in ("templates.toml", "templates-adversarial.toml", "templates-adversarial-2.toml", "templates-adversarial-3.toml")]
mutants = [
    "no-domination-clause" => :(AS.value_needed(s, p, survival, T) = (isempty(T) && return false;
        any(x -> AS.survives(s, p, x) && !AS.survives(s, p, x; silenced=Set(T)), survival))),
    "core-without-silencing-sensors" => :(AS.endogenous_core(s, pc, schedule) = (traj = AS.run_trajectory(s, pc, schedule);
        tail = traj[(end - pc.alive_window + 1):end];
        sort!(unique(u for st in tail for u in 1:AS.nunits(s) if st.active[u] && !AS.is_sensor(s, u))))),
    "no-hinge" => :(AS.core_enables_action(s, pc, c, window, core) = !isempty(core)),
    "L3-ignores-ablation" => :(AS.self_producing(s, p, pc, schedules) =
        any(x -> AS.structure_persists(s, pc, x; silenced=AS.sensor_units(s)), schedules)),
    "L3-own-activity-not-required" => :(AS.self_producing(s, p, pc, schedules) =
        !any(x -> AS.structure_persists(s, p, x; silenced=Set(1:AS.nunits(s))), schedules) &&
        any(x -> AS.structure_persists(s, p, x), schedules)),
    "tracking-any-change" => :(AS.value_tracking_units(s, pc, c, window) = (AS.value_differentiated(s, pc, c, window) || return Int[];
        base = [AS.choice(s, pc, x, window) for x in c];
        [u for u in 1:AS.nunits(s) if any(i -> AS.choice(s, pc, c[i], window; silenced=Set([u])) != base[i], 1:2)])),
]
for (name, ex) in mutants
    script = "using AgencySubstrate; const AS = AgencySubstrate; $(ex)\n" *
        "fx = $(repr(fx)); sets = [load_templates(joinpath(fx, f)) for f in (\"templates.toml\", \"templates-adversarial.toml\", \"templates-adversarial-2.toml\", \"templates-adversarial-3.toml\")]\n" *
        "bad = [t.name for set in sets for t in set.templates for r in (evaluate(t.substrate, set),) if (r.agency, r.self_producing) != (t.L2, t.L3)]\n" *
        "println(isempty(bad) ? \"SURVIVED\" : \"KILLED by \" * join(bad, \", \"))"
    out = read(`$(Base.julia_cmd()) --project=$(dirname(fx)) -e $script`, String)
    println(rpad(name, 34), strip(out))
end
