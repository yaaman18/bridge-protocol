# Candidate circuits for question (E): the pair is mutually irreplaceable, yet the pair is not
# intuitively one organization. Exploratory; changes no definition.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit

function show(name, c)
    m = MA.measure_circuit(c; all_interventions=false)
    d = MA.check_dc2(m.model)
    v3 = MA.unit_organization(c)
    groups = MA.cycle_components([Set(z) for z in v3.cycles])
    loss(u) = sort!(collect(m.losses[1 << (findfirst(==(u), c.units) - 1)]))
    println("== ", name)
    println(" κ=", sort!(collect(m.model.kappa)))
    for u in c.units
        println("  silence ", rpad(u, 3), " loss=", loss(u))
    end
    println(" N3 pairs=", d.mutual_pairs)
    println(" view1 (v3) organization cycles=", v3.cycles)
    println(" pairs inside one view1 component: ", [p for p in d.mutual_pairs if any(g -> Set(p) ⊆ g, groups)])
    println(" pairs accepted only by view2: ", [p for p in d.mutual_pairs if !any(g -> Set(p) ⊆ g, groups)])
end

# E1 mutual protection: a↔p and b↔q are two separate self-sustaining loops. A driver loop k1↔k2
# excites two inhibitors I and J. I would shut b off, J would shut a off; a keeps I off and b keeps J off.
# Silencing a releases I, which shuts b off; silencing b releases J, which shuts a off.
units = ["in", "k1", "k2", "I", "J", "a", "p", "b", "q"]
idx(u) = findfirst(==(u), units)
E(s, d, w) = [idx(s), idx(d), w]
e1 = MA.AuditCircuit(units=units, motors=["a", "b"], inputs=["in"],
    edges=[E("k1","k2",1), E("k2","k1",1), E("k1","I",1), E("k1","J",1),
           E("a","I",-1), E("b","J",-1), E("I","b",-1), E("J","a",-1),
           E("a","p",1), E("p","a",1), E("b","q",1), E("q","b",1)],
    thresholds=fill(1, 9),
    initial=[u in ("k1", "k2", "a", "p", "b", "q") for u in units], P=6, H=6, L=4, R=4)
show("E1 mutual protection (two loops guarding each other through inhibitors)", e1)

# Control: the same two loops without the guards. Nothing ties a and b together.
e0 = MA.AuditCircuit(units=units, motors=["a", "b"], inputs=["in"],
    edges=[E("k1","k2",1), E("k2","k1",1), E("a","p",1), E("p","a",1), E("b","q",1), E("q","b",1)],
    thresholds=fill(1, 9),
    initial=[u in ("k1", "k2", "a", "p", "b", "q") for u in units], P=6, H=6, L=4, R=4)
show("E0 control: the two loops alone", e0)
