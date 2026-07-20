using Random

const SIGMA1_GRID_SIZE = 8
const SIGMA1_BATCH_SIZE = 16
const SIGMA1_GENERATIONS = 200
const SIGMA1_REPLICATES = 10
const SIGMA1_BASE_SEED = 20260720
const SIGMA1_ALPHA_PRIME = 0.025
const SIGMA1_CLIFF_DELTA = 0.474

"""Read-only observation of one individual for the external QD registry."""
struct QDCandidate{T}
    individual::T
    diversity::Float64
    depth::Int
    quality::Float64
    dc_ok::Bool
    m4_safe::Bool
    hinge_nonempty::Bool
end

"""External MAP-Elites registry. It owns references, never individual state."""
struct QDArchive{T}
    cells::Dict{Tuple{Int,Int},QDCandidate{T}}
    diversity_upper::Float64
end

QDArchive{T}(diversity_upper::Real) where {T} =
    QDArchive{T}(Dict{Tuple{Int,Int},QDCandidate{T}}(), Float64(diversity_upper))

function _qd_bin(candidate::QDCandidate, diversity_upper::Real)
    diversity_upper > 0 || throw(ArgumentError("diversity_upper must be positive"))
    diversity = clamp(candidate.diversity, 0.0, Float64(diversity_upper))
    diversity_bin = min(SIGMA1_GRID_SIZE,
        floor(Int, diversity / Float64(diversity_upper) * SIGMA1_GRID_SIZE) + 1)
    depth_bin = clamp(candidate.depth, 1, SIGMA1_GRID_SIZE)
    (diversity_bin, depth_bin)
end

_qd_admissible(candidate::QDCandidate) =
    candidate.dc_ok && candidate.m4_safe && candidate.hinge_nonempty

"""Apply one external MAP-Elites placement step.

The selected path replaces a cell only on a strict quality improvement.  The
null path disables quality comparison and overwrites admitted cells, preserving
the same admission boundary without writing to any individual.
"""
function qd_selection_step(
    candidates::AbstractVector{<:QDCandidate};
    archive=nothing,
    diversity_upper::Real,
    null_selection::Bool=false,
    rng::AbstractRNG=Xoshiro(SIGMA1_BASE_SEED),
)
    isempty(candidates) && throw(ArgumentError("candidates must be nonempty"))
    individual_type = typeof(first(candidates).individual)
    registry = archive === nothing ? QDArchive{individual_type}(diversity_upper) : archive
    registry.diversity_upper == Float64(diversity_upper) ||
        throw(ArgumentError("diversity_upper is fixed when an archive is created"))

    order = randperm(rng, length(candidates))
    admitted = 0
    rejected = 0
    placed = 0
    for index in order
        candidate = candidates[index]
        if !_qd_admissible(candidate)
            rejected += 1
            continue
        end
        admitted += 1
        cell = _qd_bin(candidate, diversity_upper)
        incumbent = get(registry.cells, cell, nothing)
        if incumbent === nothing || null_selection || candidate.quality > incumbent.quality
            registry.cells[cell] = candidate
            placed += 1
        end
    end
    (; archive=registry, admitted, rejected, placed)
end

struct SigmaPurityExperiment{T,F}
    individuals::Vector{T}
    observe_trace::F
end

const _SIGMA_FORBIDDEN_SINK_CALLS = (
    "update!",
    "advance_system_adapter",
    "respond",
    "run_system_pipeline",
    "toy_recurrent_step",
)

function _sigma_static_purity(source::AbstractString)
    all(name -> !occursin(Regex("\\b" * replace(name, "!" => "\\!") * "\\s*\\("), source),
        _SIGMA_FORBIDDEN_SINK_CALLS)
end

"""Run the mandatory static and dynamic Σ-purity gates.

The dynamic gate compares ten trace observations under perturbed archive and
kernel states. Any mismatch invalidates the experiment before QD evaluation.
"""
function check_sigma_purity(
    experiment::SigmaPurityExperiment;
    source_path::AbstractString=@__FILE__,
    pairs::Integer=10,
)
    pairs == SIGMA1_REPLICATES ||
        throw(ArgumentError("the certified dynamic gate requires exactly 10 pairs"))
    isempty(experiment.individuals) &&
        throw(ArgumentError("the purity experiment requires individuals"))
    static_ok = _sigma_static_purity(read(source_path, String))
    dynamic_ok = all(1:pairs) do pair
        individual = experiment.individuals[mod1(pair, length(experiment.individuals))]
        left_state = (; archive_seed=pair, kernel_seed=SIGMA1_BASE_SEED + pair)
        right_state = (; archive_seed=pair + 10_000, kernel_seed=SIGMA1_BASE_SEED - pair)
        isequal(
            experiment.observe_trace(individual, left_state),
            experiment.observe_trace(individual, right_state),
        )
    end
    (; valid=static_ok && dynamic_ok, static_ok, dynamic_ok, pairs)
end

function _midranks(values::Vector{Float64})
    order = sortperm(values)
    ranks = zeros(Float64, length(values))
    start = 1
    while start <= length(order)
        stop = start
        while stop < length(order) && values[order[stop + 1]] == values[order[start]]
            stop += 1
        end
        rank = (start + stop) / 2
        for index in start:stop
            ranks[order[index]] = rank
        end
        start = stop + 1
    end
    ranks
end

function _exact_mann_whitney_p(left, right)
    nleft = length(left)
    nright = length(right)
    nleft == SIGMA1_REPLICATES && nright == SIGMA1_REPLICATES ||
        throw(ArgumentError("the certified test requires 10 selected and 10 null replicates"))
    ranks = _midranks(Float64.(vcat(left, right)))
    observed = sum(@view ranks[1:nleft])
    center = nleft * (nleft + nright + 1) / 2
    distance = abs(observed - center)
    total = 0
    extreme = 0
    function visit(start::Int, remaining::Int, rank_sum::Float64)
        if remaining == 0
            total += 1
            abs(rank_sum - center) + eps(Float64) >= distance && (extreme += 1)
            return
        end
        last_start = length(ranks) - remaining + 1
        for index in start:last_start
            visit(index + 1, remaining - 1, rank_sum + ranks[index])
        end
    end
    visit(1, nleft, 0.0)
    extreme / total
end

function _cliffs_delta(left, right)
    comparisons = length(left) * length(right)
    comparisons > 0 || throw(ArgumentError("samples must be nonempty"))
    (sum(x > y for x in left for y in right) -
        sum(x < y for x in left for y in right)) / comparisons
end

function _component_nondegenerate(selected, null)
    p = _exact_mann_whitney_p(selected, null)
    delta = _cliffs_delta(selected, null)
    (; p, delta, holds=p <= SIGMA1_ALPHA_PRIME && delta >= SIGMA1_CLIFF_DELTA)
end

"""Check the preregistered two-component nondegeneracy boundary."""
function check_selection_nondegenerate(selected, null)
    for field in (:depth_max, :depth_mean, :diversity_median)
        hasproperty(selected, field) && hasproperty(null, field) ||
            throw(ArgumentError("metrics must provide $field"))
    end
    depth = _component_nondegenerate(selected.depth_max, null.depth_max)
    diversity = _component_nondegenerate(selected.diversity_median, null.diversity_median)
    (; holds=depth.holds && diversity.holds, depth, diversity,
        selected_depth_mean=selected.depth_mean, null_depth_mean=null.depth_mean)
end

struct Sigma1ExperimentPlan
    replicate::Int
    seed::Int
    grid::Tuple{Int,Int}
    batch_size::Int
    generations::Int
    reference_sizes::NTuple{4,Int}
    references_per_size::Int
    random_individuals::Int
    initial_population::Int
    preregistered_rules::NTuple{4,Symbol}
end

function _sigma1_plan(replicate::Integer)
    0 <= replicate < SIGMA1_REPLICATES ||
        throw(ArgumentError("replicate must be in 0:9"))
    Sigma1ExperimentPlan(
        replicate,
        SIGMA1_BASE_SEED + replicate,
        (SIGMA1_GRID_SIZE, SIGMA1_GRID_SIZE),
        SIGMA1_BATCH_SIZE,
        SIGMA1_GENERATIONS,
        (2, 3, 8, 32),
        4,
        48,
        64,
        (:R1, :R2, :R3, :R4),
    )
end

"""Build or execute one preregistered Σ1 replicate.

Execution is opt-in because revision C requires separate user approval. When
`execute=false` (the default), this returns the frozen plan without generating
data. An approved execution must supply 64 individuals plus read-only mutation,
candidate-observation, and trace-observation callbacks.
"""
function run_sigma1_experiment(;
    replicate::Integer,
    execute::Bool=false,
    initial_population=nothing,
    mutate=nothing,
    observe_candidate=nothing,
    observe_trace=nothing,
)
    plan = _sigma1_plan(replicate)
    execute || return plan
    initial_population === nothing &&
        throw(ArgumentError("approved execution requires initial_population"))
    length(initial_population) == plan.initial_population ||
        throw(ArgumentError("initial_population must contain exactly 64 individuals"))
    mutate === nothing && throw(ArgumentError("approved execution requires mutate"))
    observe_candidate === nothing &&
        throw(ArgumentError("approved execution requires observe_candidate"))
    observe_trace === nothing &&
        throw(ArgumentError("approved execution requires observe_trace"))

    purity = check_sigma_purity(SigmaPurityExperiment(collect(initial_population), observe_trace))
    purity.valid || return (; valid=false, reason=:R1, plan, purity)

    initial_candidates = QDCandidate[observe_candidate(individual) for individual in initial_population]
    diversity_upper = 1.5 * maximum(candidate.diversity for candidate in initial_candidates)
    diversity_upper > 0 || throw(ArgumentError("initial diversity upper bound must be positive"))

    function evolve(null_selection::Bool)
        rng = Xoshiro(plan.seed)
        first_step = qd_selection_step(initial_candidates;
            diversity_upper, null_selection, rng)
        archive = first_step.archive
        rejected = first_step.rejected
        attempted = length(initial_candidates)
        coverage = Float64[length(archive.cells) / SIGMA1_GRID_SIZE^2]
        for _ in 1:plan.generations
            isempty(archive.cells) && break
            parents = collect(values(archive.cells))
            offspring = QDCandidate[]
            for _ in 1:plan.batch_size
                parent = rand(rng, parents)
                push!(offspring, observe_candidate(mutate(parent.individual, rng)))
            end
            step = qd_selection_step(offspring;
                archive, diversity_upper, null_selection, rng)
            rejected += step.rejected
            attempted += length(offspring)
            push!(coverage, length(archive.cells) / SIGMA1_GRID_SIZE^2)
        end
        (; archive, coverage, rejection_rate=rejected / attempted)
    end

    selected = evolve(false)
    null = evolve(true)
    rules = (
        R1=!purity.valid,
        R2=:pending_cross_replicate_statistics,
        R3=:pending_cross_replicate_statistics,
        R4=max(selected.rejection_rate, null.rejection_rate) > 0.90,
    )
    (; valid=true, plan, purity, selected, null, rules)
end
