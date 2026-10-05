using Test
using ERIEC
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

# View 2 (user decision 2026-10-04): part-level redundancy is judged at the two ends of a mutually
# dependent pair only. Ground truth v4: specs/packets/DC2-GROUND-TRUTH-004.md.

function v2_case(domain, case)
    found = nothing
    ModelAudit.for_each_search_circuit(domain, case + 1, 20260910) do c, id
        id == case && (found = c)
    end
    found
end
v2_pairs(c) = Set(Set(p) for p in ModelAudit.check_dc2(ModelAudit.measure_circuit(c; all_interventions=false).model).mutual_pairs)
v4_pairs(c) = Set(Set(p) for p in ModelAudit.pair_organization(c).pairs)

@testset "v4 agrees with the frozen v2 labels and planted loops" begin
    for t in ModelAudit.organization_templates(2)
        o = ModelAudit.pair_organization(ModelAudit.template_circuit(t))
        @test o.G == t["G"]
        loops = [Set(l) for l in t["planted_loops"]]
        @test all(p -> any(l -> Set(String.(p)) ⊆ l, loops), o.pairs)
    end
end

@testset "view 2 accepts the mutual-protection circuit as one organization pair" begin
    units = ["in", "k1", "k2", "I", "J", "a", "p", "b", "q"]
    E(s, d, w) = [findfirst(==(s), units), findfirst(==(d), units), w]
    e1 = ModelAudit.AuditCircuit(units=units, motors=["a", "b"], inputs=["in"],
        edges=[E("k1","k2",1), E("k2","k1",1), E("k1","I",1), E("k1","J",1),
               E("a","I",-1), E("b","J",-1), E("I","b",-1), E("J","a",-1),
               E("a","p",1), E("p","a",1), E("b","q",1), E("q","b",1)],
        thresholds=fill(1, 9), initial=[u in ("k1", "k2", "a", "p", "b", "q") for u in units],
        P=6, H=6, L=4, R=4)
    @test Set([:a, :b]) in v4_pairs(e1)
    @test Set([:a, :b]) in v2_pairs(e1)
end

@testset "the remaining differences between N3 and v4" begin
    # Known limitation (D): the pair member motor u3 is not lost by its own silencing.
    c = v2_case(:four_unit_exhaustive, 5361)
    @test Set([:u2, :u3]) in v4_pairs(c) && isempty(v2_pairs(c))
    # Only one direction of the dependence passes through a motor (u3 → u5 → u4; u4 → u3 is direct).
    c = v2_case(:six_unit_sequence, 4862)
    @test Set([:u3, :u4]) in v4_pairs(c) && !(Set([:u3, :u4]) in v2_pairs(c))
    # N3 composes two losses that do not compose: silencing u5 does not lose u4, yet N3 pairs them.
    c = v2_case(:six_unit_sequence, 1600)
    m = ModelAudit.measure_circuit(c; all_interventions=false)
    @test :u4 ∉ m.losses[1 << 4] && :u4 in m.losses[1 << 5]       # silence u5 / silence u6
    @test Set([:u4, :u5]) in v2_pairs(c) && !(Set([:u4, :u5]) in v4_pairs(c))
end

@testset "four-unit domain: N3 never claims organization v4 denies; every miss is limitation (D)" begin
    fp = 0; fn = 0; non_d = 0
    ModelAudit.for_each_search_circuit(:four_unit_exhaustive, nothing, 20260910) do c, id
        m = ModelAudit.measure_circuit(c; all_interventions=false)
        d = ModelAudit.check_dc2(m.model)
        g = ModelAudit.pair_organization(c)
        d.hUnit && !g.G && (fp += 1)
        !d.hUnit && g.G && (fn += 1)
        loss(u) = m.losses[1 << (findfirst(==(u), c.units) - 1)]
        for p in setdiff(Set(Set(p) for p in g.pairs), Set(Set(p) for p in d.mutual_pairs))
            any(a -> a in p && a ∉ loss(a), c.motors) || (non_d += 1)
        end
    end
    @test fp == 0 && fn == 48 && non_d == 0
end
