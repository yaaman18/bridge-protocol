# Sensitivity of the deepened L3 (self-repair) to the decay law: every template's L3R verdict for
# decay_period 2..32 (horizon 60, strength0 4; the damage lasts smax * decay_period steps).
using AgencySubstrate, TOML
const AS = AgencySubstrate
fx = joinpath(@__DIR__, "..", "..", "..", "tools", "AgencySubstrate", "fixtures")
files = ("templates.toml", "templates-adversarial.toml", "templates-adversarial-2.toml", "templates-adversarial-3.toml", "templates-adversarial-4.toml", "templates-repair.toml")
withdecay(q::AS.Params, d) = AS.Params(q.smax, d, q.grow_cost, q.resource0, q.rmax, q.horizon, q.alive_window, q.strength0)
for d in (2, 4, 8, 12, 15, 16, 32)
    line = String[]
    for f in files
        set = load_templates(joinpath(fx, f))
        p, pc = withdecay(set.params, d), withdecay(set.choice_params, d)
        for t in set.templates
            AS.self_repairing(t.substrate, p, pc, set.survival) && push!(line, t.name)
        end
    end
    println("decay_period=", rpad(d, 3), " lifetime=", rpad(4d, 4), " self-repairing: ", isempty(line) ? "(none)" : join(line, ", "))
end
