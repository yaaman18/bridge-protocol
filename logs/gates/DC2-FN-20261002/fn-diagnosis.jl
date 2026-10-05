# False-negative diagnosis of N3 (2026-10-02). Exploratory; changes no definition or default.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
T = Dict(t["name"] => t for t in MA.organization_templates())
built(name; kw...) = (t = merge(T[name], Dict{String,Any}(String(k) => v for (k, v) in kw)); MA.template_circuit(t))

# Direct recomputation: losses from the traces, then N3's quantifiers written out.
function direct(c::MA.AuditCircuit; motors=Set(c.motors))
    m = MA.measure_circuit(c; all_interventions=false)
    loss(u) = m.losses[1 << (findfirst(==(u), c.units) - 1)]
    rho = Dict(u => intersect(loss(u), motors) for u in c.units)
    pi = Dict(a => loss(a) for a in motors)
    produces(d, x) = any(a -> x in pi[a], rho[d])            # x ∈ Phi({d})
    K = collect(m.model.kappa)
    pairs = [(x, y) for x in K for y in K if x < y && produces(y, x) && produces(x, y)]
    (; kappa=sort!(collect(m.model.kappa)), rho=Dict(u => sort!(collect(rho[u])) for u in K), pairs)
end

println("== 2. direct recomputation on the false negatives")
for name in ("loop2-no-motor-detached", "loop2-no-motor-motor-follower", "redundant-hub", "two-loops-one-way")
    r = direct(built(name))
    println(rpad(name, 32), " κ=", r.kappa, " ρ=", r.rho, " pairs=", r.pairs)
end

println("== 3a. motor restriction: same dynamics, loop member b declared a motor / every unit an action")
for name in ("loop2-no-motor-detached", "loop2-no-motor-motor-follower")
    c = built(name)
    as_motor = built(name; motors=["m", "b"])
    println(rpad(name, 32), " N3(original)=", !isempty(direct(c).pairs),
        " N3(b motor)=", !isempty(direct(as_motor).pairs),
        " N3(all units actions)=", !isempty(direct(c; motors=Set(c.units)).pairs),
        " same κ=", direct(as_motor).kappa == direct(c).kappa)
end

println("== 3b. redundancy: loss only under joint silencing, and the redundant edge removed")
for (name, drop) in (("redundant-hub", [[2, 4, 1], [4, 2, 1]]), ("two-loops-one-way", [[3, 4, 1]]))
    c = built(name)
    full = MA.measure_circuit(c)
    collective = sort!(String.(collect(full.collective)))
    minima = Dict(String(u) => [sort!(String.([c.units[i] for i in 1:length(c.units) if (mk >> (i-1)) & 1 == 1])) for mk in full.minima[u]]
                  for u in full.model.kappa)
    pruned = built(name; edges=[e for e in T[name]["edges"] if !(e in drop)])
    println(rpad(name, 32), " collective-only losses=", collective, " minimal silencing sets=", minima,
        " | edges removed $(drop): pairs=", direct(pruned).pairs)
end

println("== 3c. windows: outcomes of the false negatives across P, H, L, R")
let changed = 0, runs = 0
    for P in (6, 10), H in (6, 10), L in (2, 4), R in (2, 4, 6), name in ("loop2-no-motor-detached", "loop2-no-motor-motor-follower", "redundant-hub")
        R <= H && L <= P + 1 || continue
        t = T[name]
        c = MA.AuditCircuit(units=t["units"], motors=t["motors"], inputs=["in"], edges=t["edges"],
            thresholds=t["thresholds"], initial=t["initial"], P=P, H=H, L=L, R=R)
        runs += 1
        MA.check_dc2(MA.measure_circuit(c; all_interventions=false).model).hUnit && (changed += 1)
    end
    println("window variants: ", runs, " runs, N3 became true in ", changed)
end
