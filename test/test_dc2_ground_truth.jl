using Test
using TOML
using SHA
using ERIEC
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

# Planted-structure ground truth for DC2's hUnit (specs/packets/DC2-GROUND-TRUTH-001.md).

const GT_FREEZE = joinpath(@__DIR__, "..", "logs", "gates", "DC2-GT-20261002", "freeze.txt")

@testset "ground-truth labels are the frozen ones" begin
    frozen = only(l for l in eachline(GT_FREEZE) if endswith(l, "organization-ground-truth.toml"))
    @test first(split(frozen)) == bytes2hex(open(sha256, ModelAudit.GROUND_TRUTH_FIXTURE))
    @test length(ModelAudit.organization_templates()) == 15
end

@testset "N3 against planted organization" begin
    r = ModelAudit.ground_truth_report()
    rows = Dict(t["name"] => t for t in r["templates"])
    # Design checks read only the trace; every template persists as designed.
    @test r["outcomes"]["design_error"] == 0
    @test r["all_order_invariant"]
    # Soundness: no false positive, and every reported pair lies inside one planted loop.
    @test r["outcomes"]["false_positive"] == 0
    @test r["unsound_pair_count"] == 0
    # The comparison is not agreement by definition: both kinds of agreement and misses occur.
    @test r["outcomes"]["true_positive"] == 9 && r["outcomes"]["true_negative"] == 3
    # Findings of 2026-10-02 (reported to the user, not yet decided): loops without a motor, and
    # loops whose members have a second sufficient source, are not detected by N3.
    @test Set(n for (n, t) in rows if t["outcome"] == "false_negative") ==
          Set(["loop2-no-motor-detached", "loop2-no-motor-motor-follower", "redundant-hub"])
    @test rows["two-loops-one-way"]["outcome"] == "true_positive"
    @test rows["two-loops-one-way"]["undetected_planted_loops"] == [["c", "d"]]
    @test r["undetected_planted_loop_count"] == 5 && r["planted_loop_count"] == 15
    # The former hUnit (IrredUnit ∧ NonSingleton) misses every planted organization.
    @test r["outcomes_v1"]["false_negative"] == 12 && r["outcomes_v1"]["true_positive"] == 0
    @test r["phenomenal_claim"] == "not_certified"
end

@testset "the pair check catches a one-directional definition" begin
    # Mutation: count c ∈ Phi({d}) alone as a pair. The follower f of loop2-follower is produced by
    # a but produces nothing, so the one-directional pair {a, f} must be flagged as unsound.
    t = only(t for t in ModelAudit.organization_templates() if t["name"] == "loop2-follower")
    m = ModelAudit.measure_circuit(ModelAudit.template_circuit(t); all_interventions=false).model
    K = collect(m.kappa)
    one_way = [Set(String.([c, d])) for c in K for d in K
               if c != d && c in ModelAudit._dc2_phi(m.pi, m.rho, Set([d]))]
    loops = [Set(l) for l in t["planted_loops"]]
    @test any(p -> !any(l -> p ⊆ l, loops), one_way)
end

@testset "v2 ground truth (user decisions of 2026-10-02)" begin
    freeze = joinpath(@__DIR__, "..", "logs", "gates", "DC2-GT-20261002", "freeze-v2.txt")
    frozen = only(l for l in eachline(freeze) if endswith(l, "organization-ground-truth-v2.toml"))
    @test first(split(frozen)) == bytes2hex(open(sha256, ModelAudit.GROUND_TRUTH_FIXTURE_V2))
    r = ModelAudit.ground_truth_report(2)
    @test r["outcomes"] == Dict("true_positive" => 9, "true_negative" => 6, "false_positive" => 0,
                                "false_negative" => 0, "design_error" => 0)
    @test r["unsound_pair_count"] == 0 && r["undetected_planted_loop_count"] == 0
    @test r["all_order_invariant"]
    # Every v2 planted loop contains a motor (decision 1).
    @test all(t -> all(l -> !isdisjoint(l, t["motors"]), t["planted_loops"]), ModelAudit.organization_templates(2))
end
