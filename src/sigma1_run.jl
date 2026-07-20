using LinearAlgebra
using Random
import TOML

const _SIGMA1_REFERENCE_SIZES = (2, 3, 8, 32)
const _SIGMA1_RANDOM_COUNT = 48
const _SIGMA1_MAX_RESAMPLES = 1000

"""Finite DC carrier plus read-only metadata used by the Σ1 adapter."""
struct Sigma1Individual
    state::ERIEState
    all_M::Vector{Int}
    all_E::Vector{Int}
    all_C::Vector{Int}
    alpha_edges::Vector{Set{Int}}
    sigma_edges::Vector{Set{Int}}
    quality_level::Int
    size_label::Int
    variant::Int
    diversity_cap::Float64
end

const _SIGMA1_REFERENCE_ARTIFACT = Ref{Union{Nothing,ObservationArtifact}}(nothing)

_sigma1_relation(edges) = source -> copy(edges[source])

function _sigma1_build_individual(
    alpha_edges::Vector{Set{Int}},
    sigma_edges::Vector{Set{Int}},
    quality_level::Integer,
    size_label::Integer,
    variant::Integer;
    diversity_cap::Real=NaN,
)
    k = length(alpha_edges)
    length(sigma_edges) == k || throw(ArgumentError("alpha and sigma carriers must agree"))
    1 <= quality_level <= k || throw(ArgumentError("quality_level must be in 1:k"))
    all_M = collect(1:k)
    all_E = collect(1:k)
    all_C = collect(1:k)
    alpha_rel = _sigma1_relation(alpha_edges)
    sigma_rel = _sigma1_relation(sigma_edges)
    pi_rel = source -> Set([source])
    rho_rel = source -> Set([source])
    kappa = _ -> Set(1:Int(quality_level))
    epsilon = _ -> Set(all_E)
    state = ERIEState{Int,Int,Int,Int}(
        alpha_rel,
        sigma_rel,
        pi_rel,
        rho_rel,
        kappa,
        epsilon,
        Set(all_C),
        0,
    )
    Sigma1Individual(
        state,
        all_M,
        all_E,
        all_C,
        deepcopy(alpha_edges),
        deepcopy(sigma_edges),
        Int(quality_level),
        Int(size_label),
        Int(variant),
        Float64(diversity_cap),
    )
end

function _sigma1_m4_safe(individual::Sigma1Individual)
    structure = individual.state.structure
    reaches = (source, target) -> any(
        target in apply(structure.pi_rel, middle)
        for middle in apply(structure.rho_rel, source)
    )
    check_terminal_guard(individual.all_C, reaches)
end

function _sigma1_admission(individual::Sigma1Individual)
    dc = check_DC(individual.state)
    (; dc, dc_ok=is_DC(dc), hinge_nonempty=!isempty(dc.act),
        m4_safe=_sigma1_m4_safe(individual))
end

function _sigma1_assert_reference(individual::Sigma1Individual)
    admission = _sigma1_admission(individual)
    admission.dc_ok || error("Σ1 reference individual failed DC admission")
    admission.hinge_nonempty || error("Σ1 reference individual has an empty hinge")
    admission.m4_safe || error("Σ1 reference individual failed M4 admission")
    all(length(targets) >= 2 for targets in individual.alpha_edges) ||
        error("Σ1 reference individual violates |alpha(a)| >= 2")
    individual
end

function _sigma1_partition_edges(k::Int, depth::Int)
    [Set(m for m in 1:k if mod1(m, depth) == mod1(source, depth)) for source in 1:k]
end

"""Construct one deterministic, self-certifying member of the 16-reference family."""
function sigma1_reference_individual(size::Integer, variant::Integer)
    k = Int(size)
    k in _SIGMA1_REFERENCE_SIZES ||
        throw(ArgumentError("reference size must be one of (2, 3, 8, 32)"))
    1 <= variant <= 4 || throw(ArgumentError("reference variant must be in 1:4"))
    depth = k == 2 ? (isodd(variant) ? 1 : 2) : min(k, Int(variant))
    quality = min(k, 1 + (Int(variant) - 1) ÷ 2)
    alpha_edges = [Set(1:k) for _ in 1:k]
    sigma_edges = _sigma1_partition_edges(k, depth)
    _sigma1_assert_reference(_sigma1_build_individual(
        alpha_edges,
        sigma_edges,
        quality,
        k,
        Int(variant),
    ))
end

function _sigma1_random_edges(rng::AbstractRNG, k::Int)
    edges = [Set{Int}() for _ in 1:k]
    for source in 1:k
        count = rand(rng, 1:k)
        union!(edges[source], randperm(rng, k)[1:count])
    end
    for target in 1:k
        target in union(edges...) || push!(edges[rand(rng, 1:k)], target)
    end
    edges
end

"""Draw one admissible random carrier, with the certified 1000-attempt bound."""
function sigma1_random_individual(
    rng::AbstractRNG;
    max_attempts::Integer=_SIGMA1_MAX_RESAMPLES,
)
    max_attempts == _SIGMA1_MAX_RESAMPLES ||
        throw(ArgumentError("the certified resampling limit is 1000"))
    for attempt in 1:max_attempts
        k = rand(rng, _SIGMA1_REFERENCE_SIZES)
        alpha_edges = _sigma1_random_edges(rng, k)
        sigma_edges = _sigma1_random_edges(rng, k)
        individual = _sigma1_build_individual(
            alpha_edges,
            sigma_edges,
            rand(rng, 1:k),
            k,
            4 + attempt,
        )
        admission = _sigma1_admission(individual)
        admission.dc_ok && admission.hinge_nonempty && admission.m4_safe && return individual
    end
    error("failed to construct an admissible Σ1 individual within 1000 attempts")
end

function _sigma1_normalized_tensor(individual::Sigma1Individual)
    incidence = relation_incidence_matrix(
        individual.state.structure.sigma_rel,
        individual.all_E,
        individual.all_M,
    )
    decomposition = svd(incidence; full=false)
    rank = count(value -> value > eps(Float64) * max(size(incidence)...) * first(decomposition.S),
        decomposition.S)
    rank > 0 || error("Σ1 observation requires a nonzero sigma relation")
    decomposition.U[:, 1:rank] * decomposition.Vt[1:rank, :]
end

function _sigma1_artifact(individual::Sigma1Individual)
    tensor = _sigma1_normalized_tensor(individual)
    wld = actuated_world(tensor)
    fingerprint = observation_system_fingerprint(
        [sort!(collect(targets)) for targets in individual.alpha_edges],
        [sort!(collect(targets)) for targets in individual.sigma_edges],
    )
    record = (
        t=0,
        T=tensor,
        V=ones(Float64, size(tensor, 2)),
        O_hat=tensor,
        wld=(
            basis=wld.basis,
            eigenvalues=wld.eigenvalues,
            dimension=size(wld.basis, 2),
            nontrivial=world_nontrivial(wld),
        ),
    )
    ObservationArtifact([record], fingerprint)
end

function _sigma1_raw_diversity(individual::Sigma1Individual, reference_artifact)
    umwelt_relative_diff(reference_artifact, _sigma1_artifact(individual)).projection_norm_diff
end

function _sigma1_reference_artifact()
    artifact = _SIGMA1_REFERENCE_ARTIFACT[]
    if artifact === nothing
        artifact = _sigma1_artifact(sigma1_reference_individual(2, 1))
        _SIGMA1_REFERENCE_ARTIFACT[] = artifact
    end
    artifact
end

function _sigma1_with_diversity_cap(individual::Sigma1Individual, cap::Real)
    _sigma1_build_individual(
        individual.alpha_edges,
        individual.sigma_edges,
        individual.quality_level,
        individual.size_label,
        individual.variant;
        diversity_cap=cap,
    )
end

function _sigma1_prepare_diversity(individuals::AbstractVector{<:Sigma1Individual})
    isempty(individuals) && throw(ArgumentError("Σ1 population must be nonempty"))
    reference_artifact = _sigma1_reference_artifact()
    raw = [_sigma1_raw_diversity(individual, reference_artifact) for individual in individuals]
    finite = filter(isfinite, raw)
    isempty(finite) && error("Σ1 population has no finite diversity witness")
    finite_max = maximum(finite)
    finite_max > 0 || error("Σ1 finite diversity maximum must be positive")
    [_sigma1_with_diversity_cap(individual, finite_max) for individual in individuals]
end

"""Build the deterministic 16 references plus 48 replicate-seeded random carriers."""
function sigma1_initial_population(replicate::Integer)
    plan = _sigma1_plan(replicate)
    rng = Xoshiro(plan.seed)
    references = Sigma1Individual[
        sigma1_reference_individual(k, variant)
        for k in _SIGMA1_REFERENCE_SIZES for variant in 1:4
    ]
    randoms = Sigma1Individual[
        sigma1_random_individual(rng) for _ in 1:_SIGMA1_RANDOM_COUNT
    ]
    _sigma1_prepare_diversity(vcat(references, randoms))
end

"""Read-only carrier-to-QDCandidate adapter."""
function sigma1_observe_candidate(individual::Sigma1Individual)
    admission = _sigma1_admission(individual)
    if !admission.dc_ok || !admission.hinge_nonempty || !admission.m4_safe
        fallback_diversity = isfinite(individual.diversity_cap) ? individual.diversity_cap : 0.0
        return QDCandidate(
            individual,
            fallback_diversity,
            1,
            Float64(length(admission.dc.act)),
            admission.dc_ok,
            admission.m4_safe,
            admission.hinge_nonempty,
        )
    end
    artifact = _sigma1_artifact(individual)
    record = last(artifact.timeseries)
    raw_diversity = umwelt_relative_diff(
        _sigma1_reference_artifact(),
        artifact,
    ).projection_norm_diff
    diversity = if isfinite(raw_diversity)
        raw_diversity
    else
        isfinite(individual.diversity_cap) && individual.diversity_cap > 0 ||
            error("Σ1 dimension mismatch requires population-level finite M_f")
        individual.diversity_cap
    end
    QDCandidate(
        individual,
        Float64(diversity),
        record.wld.dimension,
        Float64(length(admission.dc.act)),
        admission.dc_ok,
        admission.m4_safe,
        admission.hinge_nonempty,
    )
end

function _sigma1_mutate_edges(edges, target_count, operation, rng)
    mutated = deepcopy(edges)
    source = rand(rng, eachindex(mutated))
    present = collect(mutated[source])
    absent = collect(setdiff(Set(1:target_count), mutated[source]))
    if operation == 1 && !isempty(absent)
        push!(mutated[source], rand(rng, absent))
    elseif operation == 2 && !isempty(present)
        delete!(mutated[source], rand(rng, present))
    elseif operation == 3 && !isempty(present) && !isempty(absent)
        delete!(mutated[source], rand(rng, present))
        push!(mutated[source], rand(rng, absent))
    end
    mutated
end

"""Apply one non-destructive alpha-or-sigma edge mutation."""
function sigma1_mutate(individual::Sigma1Individual, rng::AbstractRNG)
    relation_choice = rand(rng, 1:2)
    operation = rand(rng, 1:3)
    alpha_edges = relation_choice == 1 ?
        _sigma1_mutate_edges(individual.alpha_edges, length(individual.all_E), operation, rng) :
        deepcopy(individual.alpha_edges)
    sigma_edges = relation_choice == 2 ?
        _sigma1_mutate_edges(individual.sigma_edges, length(individual.all_M), operation, rng) :
        deepcopy(individual.sigma_edges)
    _sigma1_build_individual(
        alpha_edges,
        sigma_edges,
        individual.quality_level,
        individual.size_label,
        individual.variant;
        diversity_cap=individual.diversity_cap,
    )
end

"""Selector-independent serialization of the protected observation trace."""
function sigma1_observe_trace(individual::Sigma1Individual, _selector=nothing)
    dc = check_DC(individual.state)
    depth = size(actuated_world(_sigma1_normalized_tensor(individual)).basis, 2)
    repr((
        sort!(collect(individual.state.kappa(individual.state.s))),
        sort!(collect(individual.state.epsilon(individual.state.s))),
        is_DC(dc),
        sort!(collect(dc.act)),
        depth,
    ))
end

function _sigma1_require_approval()
    get(ENV, "ERIEC_SIGMA1_APPROVED", "") == "true" ||
        error("Σ1 実走はユーザー承認待ち")
end

function _sigma1_trace_hashes(population)
    [begin
        individual = population[mod1(pair, length(population))]
        left_state = (; archive_seed=pair, kernel_seed=SIGMA1_BASE_SEED + pair)
        right_state = (; archive_seed=pair + 10_000, kernel_seed=SIGMA1_BASE_SEED - pair)
        left_trace = sigma1_observe_trace(individual, left_state)
        right_trace = sigma1_observe_trace(individual, right_state)
        left_hash = bytes2hex(SHA.sha256(left_trace))
        right_hash = bytes2hex(SHA.sha256(right_trace))
        (; pair, left_hash, right_hash, equal=left_hash == right_hash)
    end for pair in 1:SIGMA1_REPLICATES]
end

function _sigma1_median(values)
    ordered = sort!(Float64.(collect(values)))
    isempty(ordered) && return 0.0
    middle = length(ordered) ÷ 2
    isodd(length(ordered)) ? ordered[middle + 1] : (ordered[middle] + ordered[middle + 1]) / 2
end

function _sigma1_archive_metrics(run)
    entries = sort!(collect(run.archive.cells); by=first)
    depths = Float64[candidate.depth for (_, candidate) in entries]
    diversities = Float64[candidate.diversity for (_, candidate) in entries]
    archive = [Dict(
        "bin" => [cell[1], cell[2]],
        "depth" => candidate.depth,
        "diversity" => candidate.diversity,
        "quality" => candidate.quality,
    ) for (cell, candidate) in entries]
    Dict(
        "coverage" => run.coverage,
        "archive" => archive,
        "rejection_rate" => run.rejection_rate,
        "depth_max" => (isempty(depths) ? 0.0 : maximum(depths)),
        "depth_mean" => (isempty(depths) ? 0.0 : sum(depths) / length(depths)),
        "diversity_median" => _sigma1_median(diversities),
    )
end

function _sigma1_plan_payload(plan)
    Dict(
        "replicate" => plan.replicate,
        "seed" => plan.seed,
        "grid" => collect(plan.grid),
        "batch_size" => plan.batch_size,
        "generations" => plan.generations,
        "reference_sizes" => collect(plan.reference_sizes),
        "references_per_size" => plan.references_per_size,
        "random_individuals" => plan.random_individuals,
        "initial_population" => plan.initial_population,
        "preregistered_rules" => collect(String.(plan.preregistered_rules)),
    )
end

function _sigma1_write_toml(path, payload)
    open(path, "w") do io
        TOML.print(io, payload; sorted=true)
    end
    path
end

function _sigma1_write_replicate(output_dir, result)
    hashes = result.trace_hashes
    trace_path = joinpath(output_dir, "trace_hashes_rep$(result.plan.replicate).txt")
    open(trace_path, "w") do io
        for item in hashes
            println(io, "pair=$(item.pair) left=$(item.left_hash) right=$(item.right_hash) equal=$(item.equal)")
        end
    end
    payload = Dict(
        "valid" => result.valid,
        "plan" => _sigma1_plan_payload(result.plan),
        "purity" => Dict(
            "valid" => result.purity.valid,
            "static_runner_ok" => result.purity.static_runner_ok,
            "static_kernel_ok" => result.purity.static_kernel_ok,
            "dynamic_ok" => result.purity.dynamic_ok,
            "pairs" => [Dict(
                "pair" => item.pair,
                "left_hash" => item.left_hash,
                "right_hash" => item.right_hash,
                "equal" => item.equal,
            ) for item in hashes],
        ),
    )
    if result.valid
        payload["selected"] = _sigma1_archive_metrics(result.selected)
        payload["null"] = _sigma1_archive_metrics(result.null)
        payload["rules"] = Dict(
            String(name) => (value isa Symbol ? String(value) : value)
            for (name, value) in pairs(result.rules)
        )
    else
        payload["reason"] = String(result.reason)
    end
    _sigma1_write_toml(joinpath(output_dir, "rep$(result.plan.replicate).toml"), payload)
end

function _sigma1_git_commit()
    try
        readchomp(`git rev-parse HEAD`)
    catch
        "unavailable"
    end
end

"""Execute one approved replicate. The approval latch cannot be bypassed."""
function sigma1_execute_replicate(replicate::Integer)
    _sigma1_require_approval()
    population = sigma1_initial_population(replicate)
    runner_purity = check_sigma_purity(
        SigmaPurityExperiment(population, sigma1_observe_trace);
        source_path=@__FILE__,
    )
    trace_hashes = _sigma1_trace_hashes(population)
    hashes_equal = all(item.equal for item in trace_hashes)
    combined_runner_purity = (
        valid=runner_purity.valid && hashes_equal,
        static_runner_ok=runner_purity.static_ok,
        static_kernel_ok=true,
        dynamic_ok=runner_purity.dynamic_ok && hashes_equal,
        pairs=length(trace_hashes),
    )
    combined_runner_purity.valid || return (
        valid=false,
        reason=:R1,
        plan=_sigma1_plan(replicate),
        purity=combined_runner_purity,
        trace_hashes,
    )
    result = run_sigma1_experiment(;
        replicate,
        execute=true,
        initial_population=population,
        mutate=sigma1_mutate,
        observe_candidate=sigma1_observe_candidate,
        observe_trace=sigma1_observe_trace,
    )
    combined_purity = (
        valid=runner_purity.valid && result.purity.valid,
        static_runner_ok=runner_purity.static_ok,
        static_kernel_ok=result.purity.static_ok,
        dynamic_ok=runner_purity.dynamic_ok && result.purity.dynamic_ok &&
            all(item.equal for item in trace_hashes),
        pairs=length(trace_hashes),
    )
    merge(result, (; purity=combined_purity, trace_hashes))
end

"""Sequentially execute all ten approved replicates."""
function sigma1_run_all(; output_dir::AbstractString=joinpath("logs", "sigma1", "run-20260720"))
    _sigma1_require_approval()
    mkpath(output_dir)
    results = Any[]
    for replicate in 0:(SIGMA1_REPLICATES - 1)
        result = sigma1_execute_replicate(replicate)
        push!(results, result)
        _sigma1_write_replicate(output_dir, result)
        if !result.valid
            _sigma1_write_toml(joinpath(output_dir, "invalid.toml"), Dict(
                "valid" => false,
                "reason" => String(result.reason),
                "failed_replicate" => result.plan.replicate,
                "generated_unix" => time(),
                "git_commit" => _sigma1_git_commit(),
            ))
            return results
        end
        count(completed -> completed.valid && completed.rules.R4, results) >= 5 && break
    end
    selected = [_sigma1_archive_metrics(result.selected) for result in results]
    null = [_sigma1_archive_metrics(result.null) for result in results]
    completed_all = length(results) == SIGMA1_REPLICATES
    selected_metrics = (
        depth_max=[metrics["depth_max"] for metrics in selected],
        depth_mean=[metrics["depth_mean"] for metrics in selected],
        diversity_median=[metrics["diversity_median"] for metrics in selected],
    )
    null_metrics = (
        depth_max=[metrics["depth_max"] for metrics in null],
        depth_mean=[metrics["depth_mean"] for metrics in null],
        diversity_median=[metrics["diversity_median"] for metrics in null],
    )
    statistics = completed_all ? check_selection_nondegenerate(selected_metrics, null_metrics) : nothing
    lower_depth = completed_all ? _component_nondegenerate(null_metrics.depth_max, selected_metrics.depth_max) : nothing
    lower_diversity = completed_all ?
        _component_nondegenerate(null_metrics.diversity_median, selected_metrics.diversity_median) : nothing
    rules = Dict(
        "R1" => false,
        "R2" => (completed_all ? !statistics.depth.holds && !statistics.diversity.holds : false),
        "R3" => (completed_all ? lower_depth.holds || lower_diversity.holds : false),
        "R4" => count(result -> result.rules.R4, results) >= 5,
    )
    summary = Dict(
        "valid" => true,
        "completed_replicates" => length(results),
        "generated_unix" => time(),
        "git_commit" => _sigma1_git_commit(),
        "selected" => Dict(
            "depth_max" => selected_metrics.depth_max,
            "depth_mean" => selected_metrics.depth_mean,
            "diversity_median" => selected_metrics.diversity_median,
        ),
        "null" => Dict(
            "depth_max" => null_metrics.depth_max,
            "depth_mean" => null_metrics.depth_mean,
            "diversity_median" => null_metrics.diversity_median,
        ),
        "rules" => rules,
    )
    if completed_all
        summary["statistics"] = Dict(
            "holds" => statistics.holds,
            "depth" => Dict(
                "p" => statistics.depth.p,
                "delta" => statistics.depth.delta,
                "holds" => statistics.depth.holds,
            ),
            "diversity" => Dict(
                "p" => statistics.diversity.p,
                "delta" => statistics.diversity.delta,
                "holds" => statistics.diversity.holds,
            ),
            "selected_depth_mean" => statistics.selected_depth_mean,
            "null_depth_mean" => statistics.null_depth_mean,
        )
    end
    _sigma1_write_toml(joinpath(output_dir, "summary.toml"), summary)
    results
end
