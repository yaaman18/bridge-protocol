using LinearAlgebra

struct CriticalSlowingConfig
    lambda_threshold::Float64
    target::Float64
    eig_tol::Float64
    collapse_dimension::Int
    lead_time::Int
end

CriticalSlowingConfig(;
    lambda_threshold::Real=DEFAULT_CRITICAL_SLOWING_THRESHOLD,
    target::Real=1.0,
    eig_tol::Real=DEFAULT_EXPERIMENT_EIG_TOL,
    collapse_dimension::Integer=1,
    lead_time::Integer=5,
) = CriticalSlowingConfig(
    Float64(lambda_threshold),
    Float64(target),
    Float64(eig_tol),
    Int(collapse_dimension),
    Int(lead_time),
)

function dominant_world_eigenvalue(loop::AbstractMatrix)
    size(loop, 1) == size(loop, 2) ||
        throw(DimensionMismatch("world loop must be square"))
    maximum(real.(eigvals(Symmetric(loop))))
end

dominant_world_eigenvalue(wld_result::WldResult) =
    maximum(real.(wld_result.eigenvalues))

"""Absolute spectral distance `χ = |target - λmax|`."""
function world_chi(loop_or_world; target::Real=1.0)
    lambda = dominant_world_eigenvalue(loop_or_world)
    abs(Float64(target) - Float64(lambda))
end

function critical_slowing_score(loop_or_world; target::Real=1.0)
    gap = world_chi(loop_or_world; target=target)
    1 / (gap + eps(Float64))
end

function critical_slowing_series(loops; target::Real=1.0)
    lambdas = [dominant_world_eigenvalue(loop) for loop in loops]
    scores = [critical_slowing_score(loop; target=target) for loop in loops]
    (
        eigenvalues=lambdas,
        scores=scores,
        approaching=length(lambdas) < 2 ? false :
            abs(target - lambdas[end]) < abs(target - lambdas[1]),
    )
end

function critical_slowing_assessment(loops; config::CriticalSlowingConfig=CriticalSlowingConfig())
    series = critical_slowing_series(loops; target=config.target)
    latest = isempty(series.eigenvalues) ? NaN : Float64(last(series.eigenvalues))
    warning = !isempty(series.eigenvalues) &&
        latest >= config.lambda_threshold &&
        abs(config.target - latest) <= abs(config.target - config.lambda_threshold) + config.eig_tol
    (
        eigenvalues=series.eigenvalues,
        scores=series.scores,
        approaching=series.approaching,
        warning=warning,
        threshold=config.lambda_threshold,
        target=config.target,
        lead_time=config.lead_time,
    )
end
