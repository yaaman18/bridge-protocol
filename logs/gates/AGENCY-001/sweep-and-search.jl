# (1) How the verdicts depend on the declared decay law (AGENCY-001 §6, third falsification condition).
# (2) Discrimination over random circuits: how often agency and self-production hold, and what the
#     passing circuits look like. Exploratory; labels and criteria are not changed.
using AgencySubstrate
const AS = AgencySubstrate
base = load_templates()
function with_params(setup; decay_period)
    q = setup.params; c = setup.choice_params
    p = AS.Params(q.smax, decay_period, q.grow_cost, q.resource0, q.rmax, q.horizon, q.alive_window, q.strength0)
    pc = AS.Params(c.smax, decay_period, c.grow_cost, c.resource0, c.rmax, c.horizon, c.alive_window, c.strength0)
    merge(setup, (; params=p, choice_params=pc))
end
println("== (1) decay_period sweep (horizon $(base.params.horizon), strength0 $(base.params.strength0))")
for dp in (2, 4, 8, 12, 15, 16, 32)
    setup = with_params(base; decay_period=dp)
    row = [string(t.name, ":", evaluate(t.substrate, setup).agency ? "T" : "F", "/",
                  evaluate(t.substrate, setup).self_producing ? "T" : "F") for t in base.templates]
    println("decay_period=", rpad(dp, 3), " lifetime=", rpad(dp * base.params.strength0, 4), " L2/L3: ", join(row, "  "))
end

println("== (2) random circuits")
function random_substrate(rng_state)
    s = rng_state
    draw(k) = (s[] = s[] * 0x5851f42d4c957f2d + 0x14057b7ef767814f; Int((s[] >> 33) % UInt64(k)))
    names = ["s1", "s2", "m1", "m2", "x1", "x2", "x3"]
    n = length(names)
    edges = NTuple{3,Int}[]
    for src in 1:n, dst in 3:n          # sensors receive no edges
        src == dst && continue
        r = draw(6)
        r == 0 && push!(edges, (src, dst, -1))
        r in (1, 2) && push!(edges, (src, dst, 1))
    end
    theta = [1, 1, 1 + draw(2), 1 + draw(2), 1 + draw(2), 1 + draw(2), 1 + draw(2)]
    initial = [false, false, false, false, draw(2) == 0, draw(2) == 0, draw(2) == 0]
    AS.Substrate(names, theta, edges, Dict(3 => 1, 4 => 2), Dict(1 => 1, 2 => 2), Dict{Int,Tuple{Int,String}}(), true, initial)
end
state = Ref(UInt64(20261009))
N = 20000
agency = 0; selfprod = 0; both = 0; examples = Any[]
counts = Dict{String,Int}()
for k in 1:N
    s = random_substrate(state)
    r = evaluate(s, base)
    global agency += r.agency; global selfprod += r.self_producing; global both += r.agency && r.self_producing
    for key in (:alive_somewhere, :differentiated, :value_needed, :core_enables_action)
        counts[String(key)] = get(counts, String(key), 0) + getproperty(r, key)
    end
    isempty(r.core) || (counts["self_maintaining"] = get(counts, "self_maintaining", 0) + 1)
    if r.agency && length(examples) < 3
        push!(examples, (k, [(s.names[a], s.names[b], w) for (a, b, w) in s.edges], s.theta, r.core, r.value_tracking))
    end
end
println("circuits=", N, " agency=", agency, " self_producing=", selfprod, " both=", both)
println("component counts: ", sort!(collect(counts)))
for e in examples
    println("example #", e[1], " core=", e[4], " tracking=", e[5], " theta=", e[3])
    println("   edges=", e[2])
end
