const DEFAULT_CRITICAL_SLOWING_THRESHOLD = 0.95
const DEFAULT_EXPERIMENT_EIG_TOL = 1e-6
const DEFAULT_EXPERIMENT_SEED = 42
const DEFAULT_REPRODUCIBILITY_REPEATS = 3
const DEFAULT_REPRODUCIBILITY_REL_TOL = 0.01

struct ExperimentAcceptanceConfig
    lambda_threshold::Float64
    eig_tol::Float64
    seed::Int
    repeats::Int
    relative_tolerance::Float64
end

function ExperimentAcceptanceConfig(;
    lambda_threshold::Real=DEFAULT_CRITICAL_SLOWING_THRESHOLD,
    eig_tol::Real=DEFAULT_EXPERIMENT_EIG_TOL,
    seed::Integer=DEFAULT_EXPERIMENT_SEED,
    repeats::Integer=DEFAULT_REPRODUCIBILITY_REPEATS,
    relative_tolerance::Real=DEFAULT_REPRODUCIBILITY_REL_TOL,
)
    0 <= lambda_threshold <= 1 ||
        throw(ArgumentError("lambda_threshold must be between 0 and 1"))
    isfinite(eig_tol) && eig_tol > 0 ||
        throw(ArgumentError("eig_tol must be positive and finite"))
    repeats >= 2 || throw(ArgumentError("repeats must be at least 2"))
    isfinite(relative_tolerance) && relative_tolerance >= 0 ||
        throw(ArgumentError("relative_tolerance must be nonnegative and finite"))
    ExperimentAcceptanceConfig(
        Float64(lambda_threshold),
        Float64(eig_tol),
        Int(seed),
        Int(repeats),
        Float64(relative_tolerance),
    )
end

function reproducibility_assessment(
    values::AbstractVector{<:Real};
    config::ExperimentAcceptanceConfig=ExperimentAcceptanceConfig(),
)
    length(values) >= config.repeats ||
        throw(ArgumentError("at least $(config.repeats) repeated values are required"))
    selected = Float64.(values[1:config.repeats])
    finite = all(isfinite, selected)
    center = finite ? sum(selected) / length(selected) : NaN
    scale = finite ? max(abs(center), eps(Float64)) : NaN
    max_relative_deviation = finite ? maximum(abs.(selected .- center)) / scale : Inf
    (
        accepted=finite && max_relative_deviation <= config.relative_tolerance,
        values=selected,
        center=center,
        max_relative_deviation=max_relative_deviation,
        relative_tolerance=config.relative_tolerance,
        seed=config.seed,
        repeats=config.repeats,
    )
end

function run_reproducibility_trials(
    runner;
    metric=identity,
    config::ExperimentAcceptanceConfig=ExperimentAcceptanceConfig(),
)
    runs = [runner(config.seed, replicate) for replicate in 1:config.repeats]
    values = Float64[metric(run) for run in runs]
    (
        runs=runs,
        values=values,
        assessment=reproducibility_assessment(values; config=config),
    )
end
