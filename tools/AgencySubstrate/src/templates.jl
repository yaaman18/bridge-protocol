# Loading the frozen templates (fixtures/templates.toml).

const TEMPLATES_PATH = joinpath(@__DIR__, "..", "fixtures", "templates.toml")

_schedule(d, switch_at) = Schedule(d["name"], Tuple(d["first"]), Tuple(d["second"]), switch_at)

"""
    load_templates(path = TEMPLATES_PATH) -> NamedTuple

`params` (survival), `choice_params` (abundant resource), `survival`, `choice` (schedules),
`choice_window`, and `templates` (name, L2, L3, substrate).
"""
function load_templates(path::AbstractString=TEMPLATES_PATH)
    d = TOML.parsefile(path)
    d["schema_version"] == 1 || throw(ArgumentError("unsupported template schema"))
    q = d["params"]
    params = Params(q["smax"], q["decay_period"], q["grow_cost"], q["resource0"], q["rmax"],
        q["horizon"], q["alive_window"], q["strength0"])
    choice_params = Params(q["smax"], q["decay_period"], q["grow_cost"], q["choice_resource0"],
        q["choice_rmax"], q["horizon"], q["alive_window"], q["strength0"])
    survival = [_schedule(x, q["switch_at"]) for x in q["survival_schedules"]]
    choice = [_schedule(x, q["switch_at"]) for x in q["choice_schedules"]]
    templates = map(d["template"]) do t
        names = String.(t["units"])
        idx = Dict(u => i for (i, u) in enumerate(names))
        sub = Substrate(names, Int.(t["theta"]),
            [(idx[e[1]], idx[e[2]], Int(e[3])) for e in t["edges"]],
            Dict(idx[k] => Int(v) for (k, v) in t["motors"]),
            Dict(idx[k] => Int(v) for (k, v) in t["patch_sensors"]),
            Dict(idx[k] => (Int(v[1]), String(v[2])) for (k, v) in t["resource_sensors"]),
            t["maintain"], [u in t["initial"] for u in names])
        (name=t["name"], L2=t["L2"], L3=t["L3"], L3R=get(t, "L3R", nothing), substrate=sub)
    end
    (; params, choice_params, survival, choice, choice_window=q["choice_window"][1]:q["choice_window"][2],
       templates, sha256=bytes2hex(open(SHA.sha256, path)))
end
