using LinearAlgebra
using Random

struct FieldCoupledSystem{K,B}
    kernel::K
    action_basis::Vector{B}
    step_gain::Float64
end

struct LeniaAdapterConfig
    mu::Float64
    sigma::Float64
    dt::Float64
    tau_steps::Int
    feature_count::Int
end

function LeniaAdapterConfig(;
    mu::Real=0.15,
    sigma::Real=0.05,
    dt::Real=0.1,
    tau_steps::Integer=1,
    feature_count::Integer=6,
)
    isfinite(mu) || throw(ArgumentError("mu must be finite"))
    isfinite(sigma) && sigma > 0 || throw(ArgumentError("sigma must be positive and finite"))
    isfinite(dt) && dt > 0 || throw(ArgumentError("dt must be positive and finite"))
    tau_steps >= 1 || throw(ArgumentError("tau_steps must be positive"))
    feature_count in (6, 32, 64) ||
        throw(ArgumentError("feature_count must be one of 6, 32, or 64"))
    LeniaAdapterConfig(
        Float64(mu),
        Float64(sigma),
        Float64(dt),
        Int(tau_steps),
        Int(feature_count),
    )
end

const LeniaExperimentConditions = LeniaAdapterConfig

struct LeniaInitialConditionConfig
    mode::Symbol
    seed::Int
    baseline::Float64
    amplitude::Float64
    width::Float64
end

function LeniaInitialConditionConfig(;
    mode::Symbol=:zeros,
    seed::Integer=DEFAULT_EXPERIMENT_SEED,
    baseline::Real=0.0,
    amplitude::Real=0.1,
    width::Real=0.25,
)
    mode in (:zeros, :uniform_noise, :gaussian_blob) ||
        throw(ArgumentError("initial condition mode must be zeros, uniform_noise, or gaussian_blob"))
    isfinite(baseline) || throw(ArgumentError("initial condition baseline must be finite"))
    isfinite(amplitude) && amplitude >= 0 ||
        throw(ArgumentError("initial condition amplitude must be nonnegative and finite"))
    isfinite(width) && width > 0 ||
        throw(ArgumentError("initial condition width must be positive and finite"))
    LeniaInitialConditionConfig(
        mode,
        Int(seed),
        Float64(baseline),
        Float64(amplitude),
        Float64(width),
    )
end

function lenia_initial_field(
    shape::Tuple{Int,Int};
    config::LeniaInitialConditionConfig=LeniaInitialConditionConfig(),
)
    all(dimension -> dimension > 0, shape) ||
        throw(ArgumentError("initial field shape dimensions must be positive"))
    config.mode == :zeros && return zeros(shape)
    if config.mode == :uniform_noise
        rng = MersenneTwister(config.seed)
        noise = 2 .* rand(rng, shape...) .- 1
        return clamp.(config.baseline .+ config.amplitude .* noise, 0.0, 1.0)
    end
    xs, ys = _centered_coordinates(shape)
    radius2 = xs .^ 2 .+ ys .^ 2
    clamp.(
        config.baseline .+ config.amplitude .* exp.(-radius2 ./ (2 * config.width^2)),
        0.0,
        1.0,
    )
end

function _lenia_initial_condition_with_seed(
    config::LeniaInitialConditionConfig,
    seed::Integer,
)
    LeniaInitialConditionConfig(
        mode=config.mode,
        seed=seed,
        baseline=config.baseline,
        amplitude=config.amplitude,
        width=config.width,
    )
end

struct LeniaFieldSystem{K,B}
    kernel::K
    action_basis::Vector{B}
    config::LeniaAdapterConfig
end

function lenia_body_action_contract(
    system::LeniaFieldSystem;
    production_min_actions::Integer=16,
    production_max_actions::Integer=24,
)
    production_min_actions > 0 ||
        throw(ArgumentError("production_min_actions must be positive"))
    production_max_actions >= production_min_actions ||
        throw(ArgumentError("production_max_actions must be at least production_min_actions"))

    action_count = length(system.action_basis)
    field_shape = isempty(system.action_basis) ? nothing : size(first(system.action_basis))
    field_basis = !isempty(system.action_basis) &&
        all(basis -> basis isa AbstractMatrix && size(basis) == field_shape, system.action_basis)
    production_dimension = production_min_actions <= action_count <= production_max_actions
    (
        valid=field_basis,
        action_semantics=:field_intervention,
        kernel_parameter_role=:experiment_condition,
        action_count=action_count,
        field_shape=field_shape,
        production_dimension=production_dimension,
        profile=production_dimension ? :production : :prototype,
    )
end

check_lenia_body_action_contract(system::LeniaFieldSystem; kwargs...) =
    lenia_body_action_contract(system; kwargs...).valid

function lenia_system_fingerprint(
    system::LeniaFieldSystem,
    action::AbstractVector,
    initial_field::AbstractMatrix,
)
    length(action) == length(system.action_basis) ||
        throw(DimensionMismatch("action length must match action basis length"))
    isempty(system.action_basis) &&
        throw(ArgumentError("Lenia action basis must be nonempty"))
    size(initial_field) == size(first(system.action_basis)) ||
        throw(DimensionMismatch("initial field must match the Lenia action basis shape"))
    observation_system_fingerprint((
        kind=:LeniaFieldSystem,
        kernel=system.kernel,
        action_basis=system.action_basis,
        config=(
            mu=system.config.mu,
            sigma=system.config.sigma,
            dt=system.config.dt,
            tau_steps=system.config.tau_steps,
            feature_count=system.config.feature_count,
        ),
        action=collect(action),
        initial_field=initial_field,
    ))
end

function field_coupled_system(
    kernel::AbstractMatrix,
    action_basis::AbstractVector;
    step_gain::Real=1.0,
)
    isempty(action_basis) && throw(ArgumentError("action_basis must be non-empty"))
    size(kernel, 1) == size(kernel, 2) ||
        throw(DimensionMismatch("kernel must be square"))
    first_size = size(first(action_basis))
    all(basis -> size(basis) == first_size, action_basis) ||
        throw(DimensionMismatch("all action basis fields must have the same size"))
    FieldCoupledSystem(kernel, collect(action_basis), Float64(step_gain))
end

function field_intervention(system::FieldCoupledSystem, action::AbstractVector)
    length(action) == length(system.action_basis) ||
        throw(DimensionMismatch("action length must match action basis length"))
    intervention = zero(first(system.action_basis))
    for (coefficient, basis) in zip(action, system.action_basis)
        intervention = intervention .+ coefficient .* basis
    end
    intervention
end

function field_intervention(system::LeniaFieldSystem, action::AbstractVector)
    length(action) == length(system.action_basis) ||
        throw(DimensionMismatch("action length must match action basis length"))
    intervention = zero(first(system.action_basis))
    for (coefficient, basis) in zip(action, system.action_basis)
        intervention = intervention .+ coefficient .* basis
    end
    intervention
end

function periodic_convolution2d(field::AbstractMatrix, kernel::AbstractMatrix)
    rows, cols = size(field)
    krows, kcols = size(kernel)
    row_center = fld(krows, 2) + 1
    col_center = fld(kcols, 2) + 1
    result = zeros(eltype(field), rows, cols)
    for i in 1:rows, j in 1:cols
        acc = zero(eltype(field))
        for ki in 1:krows, kj in 1:kcols
            src_i = mod1(i + ki - row_center, rows)
            src_j = mod1(j + kj - col_center, cols)
            acc += kernel[ki, kj] * field[src_i, src_j]
        end
        result[i, j] = acc
    end
    result
end

function field_step(system::FieldCoupledSystem, field::AbstractMatrix, action::AbstractVector)
    acted = field .+ field_intervention(system, action)
    tanh.(acted .+ system.step_gain .* periodic_convolution2d(acted, system.kernel))
end

function field_features(field::AbstractMatrix)
    rows, cols = size(field)
    boundary_sum = sum(field[1, :]) + sum(field[end, :]) +
        sum(field[2:end-1, 1]) + sum(field[2:end-1, end])
    boundary_count = 2cols + 2max(rows - 2, 0)
    center = field[cld(rows, 2), cld(cols, 2)]
    upper = sum(field[1:cld(rows, 2), :])
    lower = sum(field[cld(rows, 2):end, :])
    [
        sum(field) / length(field),
        sum(abs2, field),
        boundary_sum / boundary_count,
        center,
        (upper - lower) / length(field),
        sum(abs, field) / length(field),
    ]
end

function _centered_coordinates(shape)
    rows, cols = shape
    row_center = (rows + 1) / 2
    col_center = (cols + 1) / 2
    scale = max(rows, cols) / 2
    (
        [(i - row_center) / scale for i in 1:rows, _ in 1:cols],
        [(j - col_center) / scale for _ in 1:rows, j in 1:cols],
    )
end

function lenia_gaussian_kernel(size::Integer; sigma::Real=0.22)
    size > 0 || throw(ArgumentError("kernel size must be positive"))
    isodd(size) || throw(ArgumentError("kernel size must be odd"))
    xs, ys = _centered_coordinates((size, size))
    radius2 = xs .^ 2 .+ ys .^ 2
    kernel = exp.(-radius2 ./ (2 * sigma^2))
    kernel ./ sum(kernel)
end

function lenia_action_basis(
    shape::Tuple{Int,Int};
    action_count::Integer=16,
    width::Real=0.18,
    ring_radius::Real=0.55,
)
    action_count > 0 || throw(ArgumentError("action_count must be positive"))
    xs, ys = _centered_coordinates(shape)
    [
        begin
            angle = 2pi * (index - 1) / action_count
            cx = ring_radius * cos(angle)
            cy = ring_radius * sin(angle)
            basis = exp.(-((xs .- cy) .^ 2 .+ (ys .- cx) .^ 2) ./ (2 * width^2))
            basis ./ max(maximum(basis), eps(Float64))
        end
        for index in 1:action_count
    ]
end

function _masked_mean(field::AbstractMatrix, mask::AbstractMatrix)
    weight = sum(mask)
    weight == 0 && return zero(eltype(field))
    sum(field .* mask) / weight
end

function _masked_energy(field::AbstractMatrix, mask::AbstractMatrix)
    weight = sum(mask)
    weight == 0 && return zero(eltype(field))
    sum(abs2, field .* mask) / weight
end

function lenia_features(field::AbstractMatrix; n::Integer=32)
    n == 6 && return field_features(field)
    n == 32 || n == 64 ||
        throw(ArgumentError("supported Lenia feature counts are 6, 32, and 64"))

    rows, cols = size(field)
    xs, ys = _centered_coordinates((rows, cols))
    angles = atan.(ys, xs)
    radii = sqrt.(xs .^ 2 .+ ys .^ 2)

    sector_features = [
        _masked_mean(
            field,
            Float64.((angles .>= -pi + (sector - 1) * 2pi / 16) .&
                (angles .< -pi + sector * 2pi / 16)),
        )
        for sector in 1:16
    ]
    radial_features = [
        _masked_mean(
            field,
            Float64.((radii .>= (band - 1) / 4) .& (radii .< band / 4)),
        )
        for band in 1:4
    ]
    quadrant_features = [
        _masked_mean(field, Float64.((xs .< 0) .& (ys .< 0))),
        _masked_mean(field, Float64.((xs .>= 0) .& (ys .< 0))),
        _masked_mean(field, Float64.((xs .< 0) .& (ys .>= 0))),
        _masked_mean(field, Float64.((xs .>= 0) .& (ys .>= 0))),
    ]
    base = field_features(field)
    gradients = [
        sum(field[:, 2:end] .- field[:, 1:end-1]) / max(rows * (cols - 1), 1),
        sum(field[2:end, :] .- field[1:end-1, :]) / max((rows - 1) * cols, 1),
    ]

    features32 = vcat(sector_features, radial_features, quadrant_features, base, gradients)
    n == 32 && return features32

    sector_energy = [
        _masked_energy(
            field,
            Float64.((angles .>= -pi + (sector - 1) * 2pi / 16) .&
                (angles .< -pi + sector * 2pi / 16)),
        )
        for sector in 1:16
    ]
    radial_energy = [
        _masked_energy(
            field,
            Float64.((radii .>= (band - 1) / 4) .& (radii .< band / 4)),
        )
        for band in 1:4
    ]
    quadrant_energy = [
        _masked_energy(field, Float64.((xs .< 0) .& (ys .< 0))),
        _masked_energy(field, Float64.((xs .>= 0) .& (ys .< 0))),
        _masked_energy(field, Float64.((xs .< 0) .& (ys .>= 0))),
        _masked_energy(field, Float64.((xs .>= 0) .& (ys .>= 0))),
    ]
    row_bands = [
        begin
            band_values = field[
                max(1, floor(Int, (band - 1) * rows / 4) + 1):floor(Int, band * rows / 4),
                :,
            ]
            sum(band_values) / length(band_values)
        end
        for band in 1:4
    ]
    col_bands = [
        begin
            band_values = field[
                :,
                max(1, floor(Int, (band - 1) * cols / 4) + 1):floor(Int, band * cols / 4),
            ]
            sum(band_values) / length(band_values)
        end
        for band in 1:4
    ]
    vcat(features32, sector_energy, radial_energy, quadrant_energy, row_bands, col_bands)
end

function field_system_adapter(system::FieldCoupledSystem, initial_field::AbstractMatrix)
    size(initial_field) == size(first(system.action_basis)) ||
        throw(DimensionMismatch("initial_field size must match action basis fields"))
    SigmaSystemAdapter(
        copy(initial_field),
        (field, action) -> field_step(system, field, action),
        field_features,
    )
end

lenia_growth(x; mu::Real=0.15, sigma::Real=0.05) =
    2 * exp(-((x - mu) / sigma)^2) - 1

function lenia_step_once(system::LeniaFieldSystem, field::AbstractMatrix, action::AbstractVector)
    acted = field .+ field_intervention(system, action)
    potential = periodic_convolution2d(acted, system.kernel)
    acted .+ system.config.dt .* lenia_growth.(potential; mu=system.config.mu, sigma=system.config.sigma)
end

function lenia_step(system::LeniaFieldSystem, field::AbstractMatrix, action::AbstractVector)
    system.config.tau_steps >= 1 ||
        throw(ArgumentError("tau_steps must be positive"))
    current = field
    for _ in 1:system.config.tau_steps
        current = lenia_step_once(system, current, action)
    end
    current
end

function lenia_field_system(
    kernel::AbstractMatrix,
    action_basis::AbstractVector;
    config::LeniaAdapterConfig=LeniaAdapterConfig(),
)
    isempty(action_basis) && throw(ArgumentError("action_basis must be non-empty"))
    size(kernel, 1) == size(kernel, 2) ||
        throw(DimensionMismatch("kernel must be square"))
    first_size = size(first(action_basis))
    all(basis -> size(basis) == first_size, action_basis) ||
        throw(DimensionMismatch("all action basis fields must have the same size"))
    LeniaFieldSystem(kernel, collect(action_basis), config)
end

function lenia_system_adapter(system::LeniaFieldSystem, initial_field::AbstractMatrix)
    size(initial_field) == size(first(system.action_basis)) ||
        throw(DimensionMismatch("initial_field size must match action basis fields"))
    SigmaSystemAdapter(
        copy(initial_field),
        (field, action) -> lenia_step(system, field, action),
        field -> lenia_features(field; n=system.config.feature_count),
    )
end

function default_lenia_system(
    shape::Tuple{Int,Int};
    action_count::Integer=16,
    feature_count::Integer=32,
    kernel_size::Integer=5,
    config::LeniaAdapterConfig=LeniaAdapterConfig(feature_count=feature_count),
)
    basis = lenia_action_basis(shape; action_count=action_count)
    kernel = lenia_gaussian_kernel(kernel_size)
    lenia_field_system(kernel, basis; config=config)
end
