# N3 against the v4 truth (view 2, user decision 2026-10-04) on both search domains, verdict and pair
# level (condition 2 corrected 2026-10-04). Prediction (specs/packets/DC2-GROUND-TRUTH-004.md): every difference comes from limitation (D).
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit

for domain in (:four_unit_exhaustive, :six_unit_sequence)
    n = Dict{String,Int}(); ex = Dict{String,Vector{Int}}()
    note(k, id) = (n[k] = get(n, k, 0) + 1; length(get!(ex, k, Int[])) < 3 && push!(ex[k], id))
    MA.for_each_search_circuit(domain, nothing, 20260910) do c, id
        m = MA.measure_circuit(c; all_interventions=false)
        d = MA.check_dc2(m.model)
        g = MA.pair_organization(c)
        note(d.hUnit == g.G ? (d.hUnit ? "TP" : "TN") : d.hUnit ? "FP" : "FN", id)
        mine = Set(Set(p) for p in d.mutual_pairs)
        truth = Set(Set(p) for p in g.pairs)
        loss(u) = m.losses[1 << (findfirst(==(u), c.units) - 1)]
        for p in setdiff(truth, mine)             # a v4 pair N3 misses
            x, y = collect(p)
            # Classify by the motors of the shared strongly connected component.
            reach(u, v) = v in loss(u)
            kind = if any(a -> a in (x, y) && a ∉ loss(a), c.motors)
                "K0_pair_member_motor_not_self_lost(D)"
            elseif any(a -> a ∉ (x, y) && a in loss(x) && a in loss(y) && !(x in loss(a) && y in loss(a)), c.motors)
                "K1_motor_follows_pair_its_action_not_needed"
            elseif any(a -> a ∉ (x, y) && x in loss(a) && y in loss(a) && !(a in loss(x) && a in loss(y)), c.motors)
                "K2_motor_drives_pair_without_depending_on_it"
            elseif !any(a -> a in loss(x) || a in loss(y) || x in loss(a) || y in loss(a), c.motors)
                "K3_motor_only_structurally_in_component"
            else
                "K_other"
            end
            note("pair_missed_by_N3:" * kind, id)
        end
        for p in setdiff(mine, truth)             # an N3 pair that is not a v4 pair
            x, y = collect(p)
            mutual = y in loss(x) && x in loss(y)
            note(mutual ? "pair_extra_in_N3:mutual_but_no_motor_scc" : "pair_extra_in_N3:not_mutually_lost", id)
        end
    end
    println("== ", domain)
    for k in sort!(collect(keys(n)))
        println("  ", rpad(k, 48), n[k], "  e.g. ", ex[k])
    end
end
