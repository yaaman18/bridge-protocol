# Standalone semantic experiment; never loads the eight-unit candidate or src/ERIEC.
# Not a G1-G4 gate or a certified implementation. Run from the repository root.
using Test

const State = Tuple{Vararg{Bool}}
silenced(mask, i) = !iszero(mask & (1 << (i - 1)))

function threshold_step(state, edges, thresholds, mask)
    ntuple(length(state)) do target
        total = 0
        for (source, destination, weight) in edges
            if destination == target && !silenced(mask, source) && state[source]
                total += weight  # These independent fixtures have only unit weights.
            end
        end
        total >= thresholds[target]
    end
end

function trace(step, initial, steps, mask=0)
    states = State[initial]
    for _ in 1:steps
        push!(states, step(states[end], mask))
    end
    states
end

function persistent(states, points)
    1 <= points <= length(states) || throw(ArgumentError("invalid window"))
    Set(i for i in eachindex(states[end])
        if all(states[t][i] for t in (length(states) - points + 1):length(states)))
end

function observe(step, initial; preparation, kappa_points, horizon, effect_points)
    1 <= kappa_points <= preparation + 1 || throw(ArgumentError("invalid kappa window"))
    1 <= effect_points <= horizon || throw(ArgumentError("effect window includes branch time"))
    prefix = trace(step, initial, preparation)
    anchor = prefix[end]
    branches = Dict(mask => trace(step, anchor, horizon, mask)
                    for mask in 0:((1 << length(anchor)) - 1))
    baseline = persistent(branches[0], effect_points)
    losses = Dict(mask => setdiff(baseline, persistent(states, effect_points))
                  for (mask, states) in branches)
    (; prefix, anchor, branches, losses, baseline,
       kappa=persistent(prefix, kappa_points))
end

function minimal_loss_masks(losses, target)
    # Check ALL proper subsets: loss need not be monotone for signed networks.
    Set(mask for (mask, lost) in losses if target in lost &&
        all(!(target in losses[sub]) for sub in keys(losses)
            if sub != mask && (sub & mask) == sub))
end

function unary_relations(losses, motors, n)
    pi = Dict(m => copy(losses[1 << (m - 1)]) for m in motors)
    rho = Dict(c => intersect(losses[1 << (c - 1)], motors) for c in 1:n)
    (; pi, rho)
end

function self_subset(kappa, pi, rho)
    enabled = Set{Int}()
    for c in kappa
        union!(enabled, rho[c])
    end
    image = Set{Int}()
    for m in enabled
        union!(image, pi[m])
    end
    kappa ⊆ image
end

# These are hand-specified Boolean maps, independent of the matrix interpreter.
# All fixtures have positive thresholds and no self edges.
start_ref = (x, mask) -> begin
    a, b, seed = (x[i] && !silenced(mask, i) for i in 1:3)
    (b || seed, a || seed, false)
end
start_edges = [(2, 1, 1), (3, 1, 1), (1, 2, 1), (3, 2, 1)]
feedback_ref = (x, mask) -> (x[2] && !silenced(mask, 2), x[1] && !silenced(mask, 1))
feedback_edges = [(2, 1, 1), (1, 2, 1)]
feedforward_ref = (x, mask) -> begin
    a, b, m, sink = (x[i] && !silenced(mask, i) for i in 1:4)
    (b, a, a, m)
end
feedforward_edges = [(2, 1, 1), (1, 2, 1), (1, 3, 1), (3, 4, 1)]
redundant_ref = (x, mask) -> begin
    a, b, c, d, m = (x[i] && !silenced(mask, i) for i in 1:5)
    (b, a, d, c, a || c)
end
redundant_edges = [(2, 1, 1), (1, 2, 1), (4, 3, 1), (3, 4, 1), (1, 5, 1), (3, 5, 1)]

@testset "RSB revision 2 semantic fixtures (not gates)" begin
    @testset "independent Boolean maps agree for every state and source mask" begin
        for (n, edges, reference) in ((3, start_edges, start_ref),
                                     (2, feedback_edges, feedback_ref),
                                     (4, feedforward_edges, feedforward_ref),
                                     (5, redundant_edges, redundant_ref))
            for bits in 0:((1 << n) - 1), mask in 0:((1 << n) - 1)
                initial = ntuple(i -> !iszero(bits & (1 << (i - 1))), n)
                @test threshold_step(initial, edges, ones(Int, n), mask) == reference(initial, mask)
            end
        end
    end
    @testset "startup contribution is not continuing maintenance contribution" begin
        @test trace(start_ref, (false, false, true), 2) ==
              [(false, false, true), (true, true, false), (true, true, false)]
        @test trace(start_ref, (false, false, true), 2, 4) ==
              [(false, false, true), (false, false, false), (false, false, false)]
        obs = observe(start_ref, (false, false, true);
                      preparation=2, kappa_points=2, horizon=4, effect_points=2)
        @test obs.anchor == (true, true, false)
        @test isempty(obs.losses[4])  # The seed mattered during startup only.
        @test obs.branches[4] == obs.branches[0]
    end
    @testset "one motor can have real feedback loss including itself" begin
        obs = observe(feedback_ref, (true, true);
                      preparation=2, kappa_points=2, horizon=3, effect_points=2)
        @test obs.branches[2] == [(true, true), (false, true), (false, false), (false, false)]
        rel = unary_relations(obs.losses, Set([2]), 2)
        @test rel.pi[2] == Set([1, 2])
        @test rel.rho[1] == Set([2])
        @test rel.rho[2] == Set([2])
        @test self_subset(obs.kappa, rel.pi, rel.rho)
        old_pi = Dict(2 => setdiff(rel.pi[2], Set([2])))
        old_rho = Dict(c => setdiff(rel.rho[c], Set([c])) for c in 1:2)
        @test !self_subset(obs.kappa, old_pi, old_rho)
    end
    @testset "silencing does not force the source's own state off" begin
        obs = observe(feedforward_ref, (true, true, true, true);
                      preparation=2, kappa_points=2, horizon=3, effect_points=2)
        @test obs.branches[4][2] == (true, true, true, false)
        @test all(x[3] for x in obs.branches[4])
        @test obs.losses[4] == Set([4])
    end
    @testset "redundant sources have a collective effect without a singleton effect on motor" begin
        obs = observe(redundant_ref, (true, true, true, true, true);
                      preparation=2, kappa_points=2, horizon=4, effect_points=2)
        @test !(5 in obs.losses[1]) && !(5 in obs.losses[4])
        @test 5 in obs.losses[5]
        @test minimal_loss_masks(obs.losses, 5) == Set([5, 9, 6, 10])
        rel = unary_relations(obs.losses, Set([5]), 5)
        @test all(isempty, values(rel.rho))
        @test !self_subset(obs.kappa, rel.pi, rel.rho)
        # A failed unary predicate must not erase the collective observation.
        @test length(minimal_loss_masks(obs.losses, 5)) == 4
    end
    @testset "minimal means all proper subsets, not just immediate predecessors" begin
        losses = Dict(mask => Set{Int}() for mask in 0:7)
        losses[1] = Set([1])
        losses[7] = Set([1])
        @test minimal_loss_masks(losses, 1) == Set([1])
    end
    @testset "future effect range is not capped by the pre-intervention kappa" begin
        obs = observe(start_ref, (false, false, true);
                      preparation=0, kappa_points=1, horizon=3, effect_points=2)
        @test obs.kappa == Set([3])
        @test obs.losses[4] == Set([1, 2])
        @test !issubset(obs.losses[4], obs.kappa)
    end
    @testset "changing kappa window does not rerun a different physical protocol" begin
        short = observe(start_ref, (false, false, true);
                        preparation=2, kappa_points=2, horizon=4, effect_points=2)
        long = observe(start_ref, (false, false, true);
                       preparation=2, kappa_points=3, horizon=4, effect_points=2)
        @test short.kappa == Set([1, 2]) && isempty(long.kappa)
        @test short.anchor == long.anchor
        @test short.branches == long.branches && short.losses == long.losses
        @test_throws ArgumentError observe(start_ref, (false, false, true);
            preparation=2, kappa_points=4, horizon=4, effect_points=2)
        @test_throws ArgumentError observe(start_ref, (false, false, true);
            preparation=2, kappa_points=2, horizon=4, effect_points=5)
    end
    @testset "shared physical trial gives the stated pi/rho restriction" begin
        obs = observe(redundant_ref, (true, true, true, true, true);
                      preparation=2, kappa_points=2, horizon=4, effect_points=2)
        rel = unary_relations(obs.losses, Set([5]), 5)
        @test rel.rho[5] == intersect(rel.pi[5], Set([5]))
        @test all(states[1] == obs.anchor for states in values(obs.branches))
    end
end
