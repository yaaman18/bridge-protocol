# Mutation test of the criteria (revision 2, 2026-10-24): each mutant is a textual edit of
# tools/AgencySubstrate/src/criteria.jl, loaded over the package in a fresh process; it must break the
# agreement with the frozen labels (L2, L3, L3R) of some template. The run of revision 1 (six mutants,
# four template sets) is kept as mutation-revision1.jl / mutation-revision1.out.
root = joinpath(@__DIR__, "..", "..", "..", "tools", "AgencySubstrate")
src = read(joinpath(root, "src", "criteria.jl"), String)
mutants = [
    "no-domination-clause" => ["&& all(i -> !without[i] || intact[i], eachindex(survival))" => ""],
    "core-without-silencing-sensors" => ["traj = run_trajectory(s, pc, schedule; silenced=sensor_units(s))" => "traj = run_trajectory(s, pc, schedule)"],
    "no-hinge" => ["agency=!isempty(core) && hinge &&" => "agency=!isempty(core) &&"],
    "L3-ignores-ablation" => ["!any(x -> structure_persists(s, p, x; silenced=everything), schedules) &&" => ""],
    "L3-own-activity-not-required" => ["any(x -> structure_persists(s, pc, x; silenced=sensor_units(s)), schedules)" => "any(x -> structure_persists(s, p, x), schedules)"],
    "tracking-any-change" => ["!= base[i], 1:2) == 1]" => "!= base[i], 1:2) >= 1]"],
    "tracking-includes-core" => ["T = setdiff(measured, core)" => "T = measured"],
    "repair-for-some-core-unit" => [
        "st.dead && return false" => "st.dead && continue",
        "1:nunits(s)), tail) || return false" => "1:nunits(s)), tail) || continue",
        "all(k -> st.strength[k] >= 1, constituents) || return false" => "!isempty(constituents) && all(k -> st.strength[k] >= 1, constituents) && return true",
        "    any_constituent\nend" => "    false\nend"],
    "repair-without-alive-check" => ["all(x -> any(v -> x.active[v] && !is_sensor(s, v), 1:nunits(s)), tail) || return false" => ""],
    "repair-without-self-producing" => ["self_producing(s, p, pc, schedules) || return false" => ""],
    "repair-without-constituent-requirement" => ["    any_constituent\nend" => "    true\nend"],
]
check = """
using AgencySubstrate, TOML
fx = $(repr(joinpath(root, "fixtures")))
l3r = TOML.parsefile(joinpath(fx, "labels-repair.toml"))["L3R"]
bad = String[]
for f in ("templates.toml", "templates-adversarial.toml", "templates-adversarial-2.toml", "templates-adversarial-3.toml", "templates-adversarial-4.toml", "templates-repair.toml")
    set = load_templates(joinpath(fx, f))
    for t in set.templates
        r = evaluate(t.substrate, set)
        (r.agency, r.self_producing, r.self_repairing) == (t.L2, t.L3, something(t.L3R, get(l3r, t.name, missing))) || push!(bad, t.name)
    end
end
println(isempty(bad) ? "SURVIVED" : "KILLED by " * join(bad, ", "))
"""
for (name, edits) in vcat(["none (unmutated)" => Pair{String,String}[]], mutants)
    m = src
    for (old, new) in edits
        count(old, m) == 1 || error("$name: edit target not unique: $old")
        m = replace(m, old => new)
    end
    script = "using AgencySubstrate; Base.include_string(AgencySubstrate, $(repr(m)));\n" * check
    out = read(`$(Base.julia_cmd()) --project=$root -e $script`, String)
    println(rpad(name, 40), strip(out))
end
