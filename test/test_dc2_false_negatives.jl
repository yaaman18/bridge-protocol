using Test
using ERIEC
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

# False-negative check of N3 (2026-10-02, logs/gates/DC2-FN-20261002/README.md).
# The mechanism-level truth removes the edges of one excitatory cycle; the measurement silences a
# unit's outputs. They are different interventions.

const FN_T = Dict(t["name"] => t for t in ModelAudit.organization_templates())
fn_built(name; kw...) = ModelAudit.template_circuit(
    merge(FN_T[name], Dict{String,Any}(String(k) => v for (k, v) in kw)))
fn_measure(c) = ModelAudit.measure_circuit(c; all_interventions=false)
fn_loss(m, u) = m.losses[1 << (findfirst(==(u), m.circuit.units) - 1)]

function fn_case(domain, case)
    found = nothing
    ModelAudit.for_each_search_circuit(domain, case + 1, 20260910) do c, id
        id == case && (found = c)
    end
    found
end

@testset "frozen labels agree with edge removal" begin
    for (name, t) in FN_T
        o = ModelAudit.mechanism_organization(ModelAudit.template_circuit(t))
        planted = Set(Set(l) for l in t["planted_loops"])
        @test Set(Set(String.(z)) for z in o.weak_cycles) == planted
        strict = Set(Set(String.(z)) for z in o.strict_cycles)
        # Under the strict reading the loops held up by a second sufficient source do not count.
        @test (strict == planted) == !(name in ("redundant-hub", "two-loops-one-way"))
    end
end

@testset "cause 1: production is read through motors only" begin
    for name in ("loop2-no-motor-detached", "loop2-no-motor-motor-follower")
        m = fn_measure(fn_built(name))
        # The partner is never produced through a motor: every motor lost with b (or c) produces nothing
        # in the loop (motor-follower: ρ(b) = {m} but m feeds nothing).
        motors = Set(m.circuit.motors)
        @test !any(a -> :c in fn_loss(m, a), intersect(fn_loss(m, :b), motors))
        @test !any(a -> :b in fn_loss(m, a), intersect(fn_loss(m, :c), motors))
        @test !ModelAudit.check_dc2(m.model).hUnit
        # Same dynamics, b declared a motor: the pair is found and the core is unchanged.
        m2 = fn_measure(fn_built(name; motors=["m", "b"]))
        @test ModelAudit.check_dc2(m2.model).hUnit
        @test m2.model.kappa == m.model.kappa
    end
end

@testset "cause 2: a second sufficient source hides single-unit dependence" begin
    hub = ModelAudit.measure_circuit(fn_built("redundant-hub"))
    @test isempty(fn_loss(hub, :b)) && isempty(fn_loss(hub, :c))
    units = hub.circuit.units
    bc = (1 << (findfirst(==(:b), units) - 1)) | (1 << (findfirst(==(:c), units) - 1))
    @test bc in hub.minima[:a]                            # a is lost only when b and c are both silenced
    pruned = fn_built("redundant-hub"; edges=[e for e in FN_T["redundant-hub"]["edges"] if !(e in ([2, 4, 1], [4, 2, 1]))])
    @test ModelAudit.check_dc2(fn_measure(pruned).model).hUnit
    oneway = fn_built("two-loops-one-way"; edges=[e for e in FN_T["two-loops-one-way"]["edges"] if e != [3, 4, 1]])
    @test [:c, :d] in ModelAudit.check_dc2(fn_measure(oneway).model).mutual_pairs
end

@testset "the false negatives do not depend on the windows" begin
    flipped = 0; runs = 0
    for P in (6, 10), H in (6, 10), L in (2, 4), R in (2, 4, 6),
        name in ("loop2-no-motor-detached", "loop2-no-motor-motor-follower", "redundant-hub")
        R <= H || continue
        t = FN_T[name]
        c = ModelAudit.AuditCircuit(units=t["units"], motors=t["motors"], inputs=["in"], edges=t["edges"],
            thresholds=t["thresholds"], initial=t["initial"], P=P, H=H, L=L, R=R)
        runs += 1
        ModelAudit.check_dc2(fn_measure(c).model).hUnit && (flipped += 1)
    end
    @test runs == 72 && flipped == 0
end

@testset "inspected circuits: the checker's earlier false positives were checker errors" begin
    # Late-switching units (5434, 3218), oscillating path (4652), hub without a common simple cycle (39).
    for (domain, case) in ((:four_unit_exhaustive, 5434), (:six_unit_sequence, 3218),
                           (:six_unit_sequence, 4652), (:six_unit_sequence, 39))
        c = fn_case(domain, case)
        d = ModelAudit.check_dc2(fn_measure(c).model)
        groups = ModelAudit.cycle_components([Set(z) for z in ModelAudit.mechanism_organization(c).weak_cycles])
        @test d.hUnit
        @test all(p -> any(g -> Set(p) ⊆ g, groups), d.mutual_pairs)
    end
    # Inhibitory edges are not support loops (2564): no excitatory carrying cycle, N3 false.
    c = fn_case(:six_unit_sequence, 2564)
    @test !ModelAudit.mechanism_organization(c).G_weak && !ModelAudit.check_dc2(fn_measure(c).model).hUnit
    # Shared-edge limitation (5490): u2 is a redundant branch; N3 false is consistent with silencing.
    c = fn_case(:four_unit_exhaustive, 5490)
    m = fn_measure(c)
    @test isempty(fn_loss(m, :u2)) && !ModelAudit.check_dc2(m.model).hUnit
end

@testset "weak reading: no false positive and no unsound pair on both search domains" begin
    for domain in (:four_unit_exhaustive, :six_unit_sequence)
        fp = 0; unsound = 0; tp = 0
        ModelAudit.for_each_search_circuit(domain, nothing, 20260910) do c, id
            d = ModelAudit.check_dc2(fn_measure(c).model)
            d.hUnit || return
            o = ModelAudit.mechanism_organization(c)
            o.G_weak ? (tp += 1) : (fp += 1)
            groups = ModelAudit.cycle_components([Set(z) for z in o.weak_cycles])
            unsound += count(p -> !any(g -> Set(p) ⊆ g, groups), d.mutual_pairs)
        end
        @test fp == 0 && unsound == 0
        @test tp == (domain == :four_unit_exhaustive ? 7109 : 915)
    end
end

@testset "v2 organization truth: labels and the three remaining disagreement kinds" begin
    for t in ModelAudit.organization_templates(2)
        o = ModelAudit.mechanism_organization(ModelAudit.template_circuit(t))
        @test Set(Set(String.(z)) for z in o.organization_cycles) == Set(Set(l) for l in t["planted_loops"])
    end
    # (B) path redundancy from a single source (6833): u3 gets u1 directly and through u2.
    c = fn_case(:four_unit_exhaustive, 6833); m = fn_measure(c)
    @test ModelAudit.check_dc2(m.model).hUnit && !ModelAudit.mechanism_organization(c).G_org
    @test isempty(fn_loss(m, :u2)) && :u3 in fn_loss(m, :u1)
    # (C) silencing side effect (50): cutting u5 → u4 stops u4, silencing u5 does not.
    c = fn_case(:six_unit_sequence, 50); m = fn_measure(c)
    @test ModelAudit.mechanism_organization(c).G_org && !ModelAudit.check_dc2(m.model).hUnit
    @test :u4 ∉ fn_loss(m, :u5)
    # (D) the loop's motor stays on when its own outputs are silenced (5361), so π(u3) does not contain
    # u3: the motor unit is not read as produced by its own action (the binding side is π, not ρ;
    # logs/gates/DC2-D-20261002/README.md).
    c = fn_case(:four_unit_exhaustive, 5361); m = fn_measure(c)
    @test ModelAudit.mechanism_organization(c).G_org && !ModelAudit.check_dc2(m.model).hUnit
    @test :u3 ∉ fn_loss(m, :u3) && :u2 in fn_loss(m, :u3)
end
