using Test
using TOML
using ERIEC

# RSB-PLAN-002 §6b: the written expectations of the analysis plan are checked against the
# definitions, so that a stated expectation cannot drift from them again. (The ALL-OFF row of
# the registered plan v1 expected "hSelf false", which contradicts the definition; the same
# error had been corrected once in review on 2026-09-08 and came back when v1 was frozen.)
#
# This checks the v2 DRAFT only. It never reads or runs the registered reactivation profile.

const PLAN_V2 = joinpath(@__DIR__, "..", "specs", "drafts", "reactivation-analysis-plan-v2.toml")
const DC_KEYS = Set(["dc", "hSelf", "hSMC", "hAct", "hBound"])

# Rows whose expectation is procedural (about registration, provenance or the whole enumeration),
# not about the value of a definition on a case. They carry no expected_components.
const PROCEDURAL_ROWS = Set([
    "FALSIFICATION-RSB-DISCRIMINATION", "FALSIFICATION-RSB-PROVENANCE",
    "FALSIFICATION-RSB-PROFILE-DIGEST", "FALSIFICATION-RSB-DECOUPLING"])

# Components that need DC2, beta or the redundancy classification. They are checked against the
# RSB-003 criteria in tools/ReactivationERIEC/test/runtests.jl ("analysis plan v2 rows that waited
# for RSB-003"), which this repository-level test does not load. Listed explicitly so that nothing is
# skipped silently.
const PENDING_RSB_003 = Dict(
    "FALSIFICATION-RSB-ALL-OFF" => Set(["dc2"]),
    "FALSIFICATION-RSB-DC2-IMPLIES-DC" => Set(["dc2", "hSelf", "hSMC", "hAct", "beta_nonempty"]),
    "FALSIFICATION-PLAN-DC2-GRAPH-BOUNDARY" => Set(["dc2", "hBound", "beta_nonempty"]),
    "FALSIFICATION-PLAN-REDUNDANCY" => Set(["dc", "classification"]),
)

# The profile's boundary rule "outgoing_nonzero_edges": core units with an out-neighbour outside.
graph_boundary(kappa, out) = Set(c for c in kappa if any(d -> d ∉ kappa, out[c]))

function dc_components(; alpha, sigma, pi, rho, kappa, epsilon, out)
    sys = ERIEC.ERIEState{Symbol,Symbol,Symbol,Nothing}(
        m -> copy(alpha[m]), e -> copy(sigma[e]), m -> copy(pi[m]), c -> copy(rho[c]),
        _ -> copy(kappa), _ -> copy(epsilon), graph_boundary(kappa, out), nothing)
    r = ERIEC.check_DC(sys)
    Dict("hSelf" => r.hSelf, "hSMC" => r.hSMC, "hAct" => r.hAct, "hBound" => r.hBound,
         "dc" => ERIEC.is_DC(r))
end

# Deterministic pseudo-random relations on a fixed carrier, so each expectation is checked
# against many relation choices rather than one hand-picked example.
function random_relations(seed::UInt64)
    M, E, C = [:m1, :m2], [:e1, :e2], [:m1, :m2, :e1, :e2, :c1, :c2]
    s = seed
    draw() = (s = s * 0x5851f42d4c957f2d + 0x14057b7ef767814f; Int(s >> 33))
    pick(xs) = Set(x for x in xs if draw() % 2 == 0)
    (alpha = Dict(m => pick(E) for m in M), sigma = Dict(e => pick(M) for e in E),
     pi = Dict(m => pick(C) for m in M), rho = Dict(c => pick(M) for c in C),
     out = Dict(c => pick(setdiff(C, [c])) for c in C), C = C)
end

# Fixtures: one function per row that returns the components on one relation draw.
const FIXTURES = Dict(
    # Every unit off: the core and the environment slice are empty.
    "FALSIFICATION-RSB-ALL-OFF" => rel -> dc_components(; rel.alpha, rel.sigma, rel.pi, rel.rho,
        kappa=Set{Symbol}(), epsilon=Set{Symbol}(), rel.out),
    # A nonempty core with no outgoing edge to a unit outside it.
    "FALSIFICATION-RSB-ISOLATED" => rel -> begin
        kappa = Set([:c1, :c2])
        out = copy(rel.out)
        out[:c1] = Set([:c2]); out[:c2] = Set([:c1])
        dc_components(; rel.alpha, rel.sigma, rel.pi, rel.rho, kappa, epsilon=Set([:e1]), out)
    end,
)

@testset "analysis plan v2 draft: written expectations match the definitions" begin
    plan = TOML.parsefile(PLAN_V2)
    rows = plan["falsification"]
    ids = [r["id"] for r in rows]
    @test allunique(ids)

    # Every row is either checked, pending with a named reason, or procedural. Nothing else.
    for r in rows
        id = r["id"]
        if haskey(r, "expected_components")
            @test id ∉ PROCEDURAL_ROWS
            keys_here = Set(keys(r["expected_components"]))
            pending = get(PENDING_RSB_003, id, Set{String}())
            @test pending ⊆ keys_here
            checkable = setdiff(keys_here, pending)
            @test checkable ⊆ DC_KEYS
            if !isempty(checkable)
                @test haskey(FIXTURES, id)
                for trial in 1:200
                    got = FIXTURES[id](random_relations(UInt64(trial) * 0x9e3779b97f4a7c15))
                    for k in checkable
                        @test got[k] == r["expected_components"][k]
                    end
                end
            end
        else
            @test id in PROCEDURAL_ROWS
        end
    end
    @test Set(keys(PENDING_RSB_003)) ⊆ Set(ids)
    @test PROCEDURAL_ROWS ⊆ Set(ids)

    # The two corrections of 2026-09-30.
    all_off = only(filter(r -> r["id"] == "FALSIFICATION-RSB-ALL-OFF", rows))
    @test all_off["expected_components"]["hSelf"] == true
    @test all_off["expected_components"]["hSMC"] == true
    retract = plan["decisions"]["retraction_conditions"]
    @test !any(c -> occursin("DC2 true and DC false", c), retract)
    @test any(c -> occursin("DC2 true and any of hSelf, hSMC, hAct false", c), retract)
    @test any(c -> occursin("DC2 true and beta empty", c), retract)
end

@testset "the checker catches a wrong written expectation" begin
    # Mutation: the v1 ALL-OFF expectation "hSelf false" must disagree with the definition.
    got = FIXTURES["FALSIFICATION-RSB-ALL-OFF"](random_relations(UInt64(7)))
    @test got["hSelf"] != false
    @test got["hSMC"] == true && got["hAct"] == false && got["hBound"] == false && got["dc"] == false
end
