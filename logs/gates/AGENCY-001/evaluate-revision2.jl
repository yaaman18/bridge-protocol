# Revision 2 (user decision of 2026-10-24): core units excluded from the value-tracking ablation, and
# the deepened L3 (self-repair). All five template sets against their frozen labels; L3R labels of the
# first four sets come from fixtures/labels-repair.toml.
using AgencySubstrate, TOML
fx = joinpath(@__DIR__, "..", "..", "..", "tools", "AgencySubstrate", "fixtures")
l3r = TOML.parsefile(joinpath(fx, "labels-repair.toml"))["L3R"]
agree = 0; total = 0
for f in ("templates.toml", "templates-adversarial.toml", "templates-adversarial-2.toml", "templates-adversarial-3.toml", "templates-adversarial-4.toml", "templates-repair.toml")
    set = load_templates(joinpath(fx, f))
    for t in set.templates
        r = evaluate(t.substrate, set)
        lab = (t.L2, t.L3, something(t.L3R, get(l3r, t.name, missing)))
        got = (r.agency, r.self_producing, r.self_repairing)
        ok = map(==, lab, got)
        global agree += count(ok); global total += 3
        println(rpad(f, 30), rpad(t.name, 24), " labels L2/L3/L3R=", lab, " verdicts=", got, all(ok) ? "" : "  <-- DISAGREE")
        println("    core=", r.core, " tracking(ablated)=", r.value_tracking, " tracking(measured)=", r.value_tracking_measured,
                " value_needed=", r.value_needed)
    end
end
println("agreement ", agree, "/", total)
