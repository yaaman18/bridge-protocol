# N3 against the v2 organization truth (user decisions 2026-10-02): an excitatory cycle with a motor,
# at least two core units, and every edge needed (removing p → z alone stops z). Both search domains.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit

println("== v2 labels vs single-edge removal")
for t in MA.organization_templates(2)
    o = MA.mechanism_organization(MA.template_circuit(t))
    ok = Set(Set(String.(z)) for z in o.organization_cycles) == Set(Set(l) for l in t["planted_loops"])
    println(rpad(t["name"], 32), " G2=", t["G"], " G_org=", o.G_org, " cycles==planted ", ok)
end

for domain in (:four_unit_exhaustive, :six_unit_sequence)
    n = Dict{String,Int}(); ex = Dict{String,Vector{Int}}()
    note(k, id) = (n[k] = get(n, k, 0) + 1; push!(get!(ex, k, Int[]), id))
    MA.for_each_search_circuit(domain, nothing, 20260910) do c, id
        m = MA.measure_circuit(c; all_interventions=false)
        d = MA.check_dc2(m.model)
        o = MA.mechanism_organization(c)
        loss(u) = m.losses[1 << (findfirst(==(u), c.units) - 1)]
        groups = MA.cycle_components([Set(z) for z in o.organization_cycles])
        for p in d.mutual_pairs
            any(g -> Set(p) ⊆ g, groups) || note("unsound_pair", id)
        end
        if d.hUnit == o.G_org
            note(d.hUnit ? "true_positive" : "true_negative", id)
        elseif d.hUnit
            # (B) every N3 pair is mutually necessary at the unit level, but some member has a second
            # path from the same source, so no cycle has every edge needed.
            # Partial check of (B), not by elimination alone: each N3 pair lies on (or in a component of)
            # excitatory cycles that carry persistence in the weak reading, while no cycle has every edge
            # needed (that is what false positive means here). That the unneeded edge is backed by a second
            # path from the same source is confirmed only for the inspected cases 6833 and 11475.
            verified = all(d.mutual_pairs) do pr
                cyc = [z for z in o.weak_cycles if Set(pr) ⊆ Set(z)]
                !isempty(cyc) || any(g -> Set(pr) ⊆ g, MA.cycle_components([Set(z) for z in o.weak_cycles]))
            end
            note(verified ? "fp_path_redundancy_single_source" : "fp_other", id)
        else
            # (C) an organization cycle edge p → z is needed, yet silencing p does not lose z: silencing
            # also removes p's other (e.g. inhibitory) outputs, which changes other units.
            side = any(o.organization_cycles) do z
                any(k -> z[mod1(k + 1, length(z))] ∉ loss(z[k]), eachindex(z))
            end
            # (D) the motor on an organization cycle stays on when its own outputs are silenced, so its
            # action is not read as lost. (Corrected 2026-10-02 by the D trial: the binding side is
            # π(a) = loss(a) ∌ a, the motor unit is not read as produced by its own action.)
            motor_kept = any(o.organization_cycles) do z
                any(a -> a in c.motors && a ∉ loss(a), z)
            end
            note(side ? "fn_silencing_side_effect" : motor_kept ? "fn_motor_not_lost_by_own_silencing" : "fn_other", id)
        end
    end
    println(domain, " ", sort!([k => v for (k, v) in n]), " first ", sort!([k => first(v, 3) for (k, v) in ex if !startswith(k, "true")]))
end
