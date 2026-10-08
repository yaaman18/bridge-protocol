# Candidate C against the frozen 15 templates (v2 labels) and the hinge question.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit

# A multi-part unit under C: an inclusion-minimal nonempty post-fixed subset of κ with ≥2 members.
function c_multi_unit(c; relativize=true)
    units, n = c.units, length(c.units)
    m = MA.measure_circuit(c)
    full = (1 << n) - 1
    bit(u) = 1 << (findfirst(==(u), units) - 1)
    mask_of(Y) = foldl((acc, u) -> acc | bit(u), Y; init=0)
    eps_mask = relativize ? mask_of(m.model.epsilon) : 0
    # C_min: every inclusion-minimal loss set of u meets Y ∪ ε (monotone by construction)
    C_min(Y) = Set(u for u in units if !isempty(m.minima[u]) &&
                   all(a -> a & (mask_of(Y) | eps_mask) != 0, m.minima[u]))
    core = sort!(collect(m.model.kappa))
    k = length(core)
    post = falses(1 << k)
    for v in 1:((1 << k) - 1)
        Y = Set(core[i] for i in eachindex(core) if (v >> (i - 1)) & 1 == 1)
        post[v + 1] = Y ⊆ C_min(Y)
    end
    mins = Vector{Vector{Symbol}}()
    for v in 1:((1 << k) - 1)
        post[v + 1] || continue
        sub = (v - 1) & v
        proper = false
        while sub != 0
            post[sub + 1] && (proper = true; break)
            sub = (sub - 1) & v
        end
        proper && continue
        count_ones(v) >= 2 && push!(mins, [core[i] for i in eachindex(core) if (v >> (i - 1)) & 1 == 1])
    end
    (; multi=!isempty(mins), units=mins, kappa=core)
end

println("== 15 templates: v2 labels vs C and vs N3")
const AG = Dict("c" => 0, "n3" => 0)
for t in MA.organization_templates(2)
    circ = MA.template_circuit(t)
    cu = c_multi_unit(circ)
    n3 = MA.check_dc2(MA.measure_circuit(circ; all_interventions=false).model).hUnit
    AG["c"] += cu.multi == t["G"]; AG["n3"] += n3 == t["G"]
    println(rpad(t["name"], 32), " G=", rpad(string(t["G"]), 6), " N3=", rpad(string(n3), 6),
            " C=", rpad(string(cu.multi), 6), cu.multi ? string(" units=", cu.units) : "")
end
println("agreement: C ", AG["c"], "/15   N3 ", AG["n3"], "/15")

println("\n== the hinge question on the audit domains (cores only)")
for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 6000))
    cores = 0; eps_c = 0; eps_c_no_act = 0; naive_c = 0; naive_c_no_act = 0
    MA.for_each_search_circuit(domain, limit, 20260910) do c, id
        units, n = c.units, length(c.units)
        m = MA.measure_circuit(c)
        isempty(m.model.kappa) && return
        cores += 1
        full = (1 << n) - 1
        bit(u) = 1 << (findfirst(==(u), units) - 1)
        mask_of(Y) = foldl((acc, u) -> acc | bit(u), Y; init=0)
        km = mask_of(m.model.kappa); em = mask_of(m.model.epsilon)
        act_empty = isempty(MA.check_dc2(m.model).act)
        keeps(keep) = m.model.kappa ⊆ Set(u for u in units if u in m.baseline && u ∉ m.losses[full & ~keep])
        keeps(km | em) && (eps_c += 1; act_empty && (eps_c_no_act += 1))
        keeps(km) && (naive_c += 1; act_empty && (naive_c_no_act += 1))
    end
    println(domain, ": cores=", cores,
            "  ε-C holds=", eps_c, " of which Act empty=", eps_c_no_act,
            "  naive C holds=", naive_c, " of which Act empty=", naive_c_no_act)
end
