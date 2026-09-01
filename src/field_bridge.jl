import SHA
using TOML

const SENSORY_CARRIER_PROFILE_PATH = normpath(joinpath(
    @__DIR__, "..", "specs", "sensory-carrier-profile-v1.toml",
))

struct SensoryCarrierProfile
    profile_id::String
    body_threshold::Float64
    minimum_area::Int
    smoothing_sigma::Float64
    minimum_normal_norm::Float64
    angular_sectors::Int
    radial_bands::Int
    persistence_horizon::Int
    minimum_recentered_iou::Float64
    absolute_tolerance::Float64
    relative_tolerance::Float64
end

function load_sensory_carrier_profile(path::AbstractString=SENSORY_CARRIER_PROFILE_PATH)
    parsed = TOML.parsefile(path)
    parsed["schema_version"] == 1 ||
        throw(ArgumentError("unsupported sensory carrier profile schema"))
    grid = parsed["grid"]
    body = parsed["body"]
    features = parsed["features"]
    persistence = parsed["persistence"]
    measurement = parsed["measurement"]
    grid["requires_square"] == true ||
        throw(ArgumentError("P0 requires a square periodic grid"))
    grid["periodic"] == true ||
        throw(ArgumentError("P0 requires periodic boundaries"))
    features["channel_count"] ==
        4features["angular_sectors"] + features["radial_bands"] ||
        throw(ArgumentError("sensory channel_count does not match its families"))
    SensoryCarrierProfile(
        parsed["profile_id"],
        body["threshold"],
        body["minimum_area"],
        body["mask_smoothing_sigma_cells"],
        body["minimum_normal_norm"],
        features["angular_sectors"],
        features["radial_bands"],
        persistence["horizon_steps"],
        persistence["minimum_recentered_iou"],
        measurement["feature_change_absolute_tolerance"],
        measurement["feature_change_relative_tolerance"],
    )
end

struct ObstacleField
    mask::BitMatrix
end

ObstacleField(mask::AbstractMatrix{Bool}) = ObstacleField(BitMatrix(mask))

struct BodyGeometry
    support::BitMatrix
    boundary::BitMatrix
    center::NTuple{2,Float64}
    radius::Float64
    normal_row::Matrix{Float64}
    normal_col::Matrix{Float64}
    curvature::Matrix{Float64}
end

struct BodyGeometryResult
    valid::Bool
    reason::Symbol
    geometry::Union{BodyGeometry,Nothing}
end

struct GeometricSensoryState
    channels::Vector{Tuple{Symbol,Int}}
    values::Vector{Float64}
end

Base.length(state::GeometricSensoryState) = length(state.channels)

struct AlphaTrialProvenance
    sha256::String
end

struct ClampSigmaTrialProvenance
    sha256::String
end

alpha_trial_provenance(payload) =
    AlphaTrialProvenance(bytes2hex(SHA.sha256(repr(payload))))
clamp_sigma_trial_provenance(payload) =
    ClampSigmaTrialProvenance(bytes2hex(SHA.sha256(repr(payload))))

struct PairedInterventionTrial{M,E}
    action::M
    features::Vector{E}
    control::Vector{Float64}
    intervened::Vector{Float64}
    provenance::AlphaTrialProvenance

    function PairedInterventionTrial(
        action::M,
        features::AbstractVector{E},
        control::AbstractVector,
        intervened::AbstractVector,
        provenance::AlphaTrialProvenance,
    ) where {M,E}
        length(features) == length(control) == length(intervened) ||
            throw(DimensionMismatch("paired trial feature vectors must have equal lengths"))
        length(unique(features)) == length(features) ||
            throw(ArgumentError("paired trial features must be unique"))
        new{M,E}(
            action,
            collect(features),
            Float64.(control),
            Float64.(intervened),
            provenance,
        )
    end
end

struct ClampTrial{M,E}
    feature::E
    action::M
    retained::Bool
    provenance::ClampSigmaTrialProvenance
end

struct ClampSigmaMeasurementCertificate{M,E}
    actions::Vector{M}
    features::Vector{E}
    alpha_relation::Dict{M,Set{E}}
    measured_sigma::Dict{E,Set{M}}
    theoretical_sigma::Dict{E,Set{M}}
    alpha_provenance::AlphaTrialProvenance
    sigma_provenance::ClampSigmaTrialProvenance
    identification_assumption::Symbol
    profile_id::String
    profile_sha256::String
    numeric_assumptions::NamedTuple
end

function _periodic_neighbors(index, shape, connectivity::Integer)
    row, col = Tuple(index)
    offsets = connectivity == 4 ?
        ((-1, 0), (1, 0), (0, -1), (0, 1)) :
        Tuple((dr, dc) for dr in -1:1 for dc in -1:1 if !(dr == 0 && dc == 0))
    CartesianIndex[
        CartesianIndex(mod1(row + dr, shape[1]), mod1(col + dc, shape[2]))
        for (dr, dc) in offsets
    ]
end

function _periodic_components(mask::BitMatrix; connectivity::Integer=8)
    visited = falses(size(mask))
    components = Vector{Vector{CartesianIndex{2}}}()
    for seed in CartesianIndices(mask)
        (!mask[seed] || visited[seed]) && continue
        component = CartesianIndex{2}[]
        queue = [seed]
        visited[seed] = true
        cursor = 1
        while cursor <= length(queue)
            point = queue[cursor]
            cursor += 1
            push!(component, point)
            for neighbor in _periodic_neighbors(point, size(mask), connectivity)
                if mask[neighbor] && !visited[neighbor]
                    visited[neighbor] = true
                    push!(queue, neighbor)
                end
            end
        end
        push!(components, component)
    end
    components
end

function _periodic_center(field::AbstractMatrix, support::BitMatrix, minimum_norm::Real)
    rows, cols = size(field)
    weights = max.(Float64.(field), 0.0) .* support
    sum(weights) > 0 || return nothing
    row_vector = sum(
        weights[row, col] * cis(2pi * (row - 1) / rows)
        for row in 1:rows, col in 1:cols
    )
    col_vector = sum(
        weights[row, col] * cis(2pi * (col - 1) / cols)
        for row in 1:rows, col in 1:cols
    )
    abs(row_vector) > minimum_norm && abs(col_vector) > minimum_norm || return nothing
    row_angle = mod(angle(row_vector), 2pi)
    col_angle = mod(angle(col_vector), 2pi)
    (1 + rows * row_angle / (2pi), 1 + cols * col_angle / (2pi))
end

_wrapped_delta(value::Real, center::Real, period::Integer) =
    mod(value - center + period / 2, period) - period / 2

function _periodic_gradient(values::AbstractMatrix)
    row = (circshift(values, (-1, 0)) .- circshift(values, (1, 0))) ./ 2
    col = (circshift(values, (0, -1)) .- circshift(values, (0, 1))) ./ 2
    Float64.(row), Float64.(col)
end

function _periodic_gaussian_kernel(sigma::Real)
    radius = max(1, ceil(Int, 3sigma))
    axis = collect(-radius:radius)
    kernel = [exp(-(row^2 + col^2) / (2sigma^2)) for row in axis, col in axis]
    kernel ./ sum(kernel)
end

function extract_body_geometry(
    field::AbstractMatrix,
    obstacle::ObstacleField;
    profile::SensoryCarrierProfile=load_sensory_carrier_profile(),
)
    size(field) == size(obstacle.mask) ||
        throw(DimensionMismatch("field and obstacle mask must have the same shape"))
    size(field, 1) == size(field, 2) ||
        return BodyGeometryResult(false, :nonsquare_grid, nothing)
    candidate = BitMatrix((field .>= profile.body_threshold) .& .!obstacle.mask)
    components = _periodic_components(candidate; connectivity=8)
    isempty(components) && return BodyGeometryResult(false, :body_support_absent, nothing)
    sizes = length.(components)
    largest = maximum(sizes)
    largest >= profile.minimum_area ||
        return BodyGeometryResult(false, :body_support_too_small, nothing)
    count(==(largest), sizes) == 1 ||
        return BodyGeometryResult(false, :body_support_ambiguous, nothing)
    support = falses(size(candidate))
    support[components[argmax(sizes)]] .= true
    center = _periodic_center(field, support, profile.minimum_normal_norm)
    center === nothing && return BodyGeometryResult(false, :body_center_undefined, nothing)
    boundary = falses(size(support))
    for point in CartesianIndices(support)
        support[point] || continue
        boundary[point] = any(
            neighbor -> !support[neighbor],
            _periodic_neighbors(point, size(support), 4),
        )
    end
    any(boundary) || return BodyGeometryResult(false, :body_boundary_absent, nothing)
    smooth = periodic_convolution2d(
        Float64.(support),
        _periodic_gaussian_kernel(profile.smoothing_sigma),
    )
    grad_row, grad_col = _periodic_gradient(smooth)
    norm = sqrt.(grad_row .^ 2 .+ grad_col .^ 2)
    normal_row = zeros(size(field))
    normal_col = zeros(size(field))
    valid_norm = norm .> profile.minimum_normal_norm
    normal_row[valid_norm] .= -grad_row[valid_norm] ./ norm[valid_norm]
    normal_col[valid_norm] .= -grad_col[valid_norm] ./ norm[valid_norm]
    dnormal_row, _ = _periodic_gradient(normal_row)
    _, dnormal_col = _periodic_gradient(normal_col)
    curvature = dnormal_row .+ dnormal_col
    radius = maximum(
        hypot(
            _wrapped_delta(point[1], center[1], size(field, 1)),
            _wrapped_delta(point[2], center[2], size(field, 2)),
        )
        for point in findall(support)
    )
    radius > 0 || return BodyGeometryResult(false, :body_radius_zero, nothing)
    BodyGeometryResult(
        true,
        :ok,
        BodyGeometry(
            support,
            boundary,
            center,
            radius,
            normal_row,
            normal_col,
            curvature,
        ),
    )
end

function _sector(point, geometry::BodyGeometry, shape, count::Integer)
    row_delta = _wrapped_delta(point[1], geometry.center[1], shape[1])
    col_delta = _wrapped_delta(point[2], geometry.center[2], shape[2])
    theta = mod(atan(row_delta, col_delta), 2pi)
    min(floor(Int, count * theta / (2pi)) + 1, count)
end

function _sector_means(values, geometry::BodyGeometry, selector, count::Integer)
    sums = zeros(count)
    counts = zeros(Int, count)
    for point in findall(selector)
        sector = _sector(point, geometry, size(selector), count)
        sums[sector] += values[point]
        counts[sector] += 1
    end
    [counts[index] == 0 ? 0.0 : sums[index] / counts[index] for index in 1:count]
end

function extract_geometric_sensory(
    system::LeniaFieldSystem,
    field::AbstractMatrix,
    obstacle::ObstacleField;
    profile::SensoryCarrierProfile=load_sensory_carrier_profile(),
)
    result = extract_body_geometry(field, obstacle; profile=profile)
    result.valid || return (valid=false, reason=result.reason, state=nothing)
    geometry = result.geometry::BodyGeometry
    sectors = profile.angular_sectors
    boundary_points = findall(geometry.boundary)
    boundary_mass_sums = zeros(sectors)
    for point in boundary_points
        boundary_mass_sums[_sector(point, geometry, size(field), sectors)] +=
            max(Float64(field[point]), 0.0)
    end
    total_boundary_mass = sum(boundary_mass_sums)
    boundary_sector = total_boundary_mass == 0 ?
        zeros(sectors) : boundary_mass_sums ./ total_boundary_mass

    grad_row, grad_col = _periodic_gradient(Float64.(field))
    radial_sums = zeros(profile.radial_bands)
    radial_counts = zeros(Int, profile.radial_bands)
    for point in findall(geometry.support)
        dr = _wrapped_delta(point[1], geometry.center[1], size(field, 1))
        dc = _wrapped_delta(point[2], geometry.center[2], size(field, 2))
        radius = hypot(dr, dc)
        radius <= profile.minimum_normal_norm && continue
        band = clamp(
            floor(Int, profile.radial_bands * radius / geometry.radius) + 1,
            1,
            profile.radial_bands,
        )
        radial_sums[band] += grad_row[point] * dr / radius + grad_col[point] * dc / radius
        radial_counts[band] += 1
    end
    radial_gradient = [
        radial_counts[index] == 0 ? 0.0 : radial_sums[index] / radial_counts[index]
        for index in 1:profile.radial_bands
    ]

    potential = periodic_convolution2d(Float64.(field), system.kernel)
    potential_row, potential_col = _periodic_gradient(potential)
    normal_flux_values =
        .-(potential_row .* geometry.normal_row .+ potential_col .* geometry.normal_col)
    normal_flux = _sector_means(
        normal_flux_values,
        geometry,
        geometry.boundary,
        sectors,
    )
    curvature_shape = _sector_means(
        geometry.curvature,
        geometry,
        geometry.boundary,
        sectors,
    )
    contact_values = zeros(size(field))
    for point in boundary_points
        contact_values[point] = any(
            neighbor -> obstacle.mask[neighbor],
            _periodic_neighbors(point, size(field), 8),
        )
    end
    contact_obstacle = _sector_means(
        contact_values,
        geometry,
        geometry.boundary,
        sectors,
    )

    channels = vcat(
        [(:boundary_sector, index) for index in 1:sectors],
        [(:radial_gradient, index) for index in 1:profile.radial_bands],
        [(:normal_flux, index) for index in 1:sectors],
        [(:curvature_shape, index) for index in 1:sectors],
        [(:contact_obstacle, index) for index in 1:sectors],
    )
    values = vcat(
        boundary_sector,
        radial_gradient,
        normal_flux,
        curvature_shape,
        contact_obstacle,
    )
    (valid=true, reason=:ok, state=GeometricSensoryState(channels, values))
end

function _shift_support_to_center(mask::BitMatrix, center, target_center)
    row_shift = round(Int, target_center[1] - center[1])
    col_shift = round(Int, target_center[2] - center[2])
    BitMatrix(circshift(mask, (row_shift, col_shift)))
end

function check_body_persistence(
    fields::AbstractVector,
    obstacle::ObstacleField;
    profile::SensoryCarrierProfile=load_sensory_carrier_profile(),
)
    length(fields) >= profile.persistence_horizon + 1 ||
        return (ok=false, reason=:insufficient_horizon, minimum_iou=0.0)
    results = [
        extract_body_geometry(field, obstacle; profile=profile)
        for field in fields[1:(profile.persistence_horizon + 1)]
    ]
    invalid = findfirst(result -> !result.valid, results)
    invalid === nothing ||
        return (ok=false, reason=results[invalid].reason, minimum_iou=0.0)
    reference = results[1].geometry::BodyGeometry
    ious = Float64[]
    for result in results[2:end]
        geometry = result.geometry::BodyGeometry
        aligned = _shift_support_to_center(
            geometry.support,
            geometry.center,
            reference.center,
        )
        union_count = count(reference.support .| aligned)
        intersection_count = count(reference.support .& aligned)
        push!(ious, union_count == 0 ? 0.0 : intersection_count / union_count)
    end
    minimum_iou = minimum(ious)
    (
        ok=minimum_iou >= profile.minimum_recentered_iou,
        reason=minimum_iou >= profile.minimum_recentered_iou ? :ok : :coherence_failed,
        minimum_iou=minimum_iou,
    )
end

function lenia_obstacle_step_once(
    system::LeniaFieldSystem,
    field::AbstractMatrix,
    action::AbstractVector,
    obstacle::ObstacleField,
)
    size(field) == size(obstacle.mask) ||
        throw(DimensionMismatch("field and obstacle mask must have the same shape"))
    current = copy(field)
    current[obstacle.mask] .= zero(eltype(current))
    intervention = field_intervention(system, action)
    intervention = copy(intervention)
    intervention[obstacle.mask] .= zero(eltype(intervention))
    acted = current .+ intervention
    potential = periodic_convolution2d(acted, system.kernel)
    updated = acted .+ system.config.dt .* lenia_growth.(
        potential;
        mu=system.config.mu,
        sigma=system.config.sigma,
    )
    updated[obstacle.mask] .= zero(eltype(updated))
    updated
end

function lenia_obstacle_step(
    system::LeniaFieldSystem,
    field::AbstractMatrix,
    action::AbstractVector,
    obstacle::ObstacleField,
)
    current = copy(field)
    for _ in 1:system.config.tau_steps
        current = lenia_obstacle_step_once(system, current, action, obstacle)
    end
    current
end

function estimate_alpha_relation(
    trials::AbstractVector{<:PairedInterventionTrial};
    profile::SensoryCarrierProfile=load_sensory_carrier_profile(),
)
    isempty(trials) && throw(ArgumentError("alpha estimation requires paired trials"))
    Dict(
        trial.action => Set(
            trial.features[index]
            for index in eachindex(trial.features)
            if abs(trial.intervened[index] - trial.control[index]) >
                max(
                    profile.absolute_tolerance,
                    profile.relative_tolerance * abs(trial.control[index]),
                )
        )
        for trial in trials
    )
end

function estimate_clamp_sigma_relation(trials::AbstractVector{<:ClampTrial})
    isempty(trials) && throw(ArgumentError("sigma estimation requires clamp trials"))
    features = unique(trial.feature for trial in trials)
    Dict(
        feature => Set(
            trial.action for trial in trials
            if trial.feature == feature && trial.retained
        )
        for feature in features
    )
end

function alpha_relation_nondegeneracy(actions, features, alpha_relation)
    action_set = Set(actions)
    length(action_set) == length(actions) || return false
    all(action -> haskey(alpha_relation, action), actions) || return false
    all(features) do feature
        influenced = count(action -> feature in alpha_relation[action], actions)
        0 < influenced < length(actions)
    end
end

sensory_carrier_profile_sha256(path::AbstractString=SENSORY_CARRIER_PROFILE_PATH) =
    bytes2hex(SHA.sha256(read(path)))

function check_measured_hconv(actions, features, alpha_relation, sigma_relation)
    all(actions) do action
        haskey(alpha_relation, action) || return false
        all(features) do feature
            haskey(sigma_relation, feature) || return false
            (feature in alpha_relation[action]) == (action in sigma_relation[feature])
        end
    end
end

function check_clamp_sigma_identification(cert::ClampSigmaMeasurementCertificate)
    action_set = Set(cert.actions)
    feature_set = Set(cert.features)
    complete =
        length(action_set) == length(cert.actions) &&
        length(feature_set) == length(cert.features) &&
        Set(keys(cert.alpha_relation)) == action_set &&
        Set(keys(cert.measured_sigma)) == feature_set &&
        Set(keys(cert.theoretical_sigma)) == feature_set &&
        all(values(cert.alpha_relation)) do image
            image ⊆ feature_set
        end &&
        all(values(cert.measured_sigma)) do image
            image ⊆ action_set
        end &&
        all(values(cert.theoretical_sigma)) do image
            image ⊆ action_set
        end
    provenance_independent =
        !isempty(cert.alpha_provenance.sha256) &&
        !isempty(cert.sigma_provenance.sha256) &&
        cert.alpha_provenance.sha256 != cert.sigma_provenance.sha256
    identifies = complete && all(
        cert.measured_sigma[feature] == cert.theoretical_sigma[feature]
        for feature in cert.features
    )
    hconv = complete && check_measured_hconv(
        cert.actions,
        cert.features,
        cert.alpha_relation,
        cert.measured_sigma,
    )
    (
        ok=complete && provenance_independent && identifies &&
            cert.identification_assumption == :clamp_identifies_theoretical_sigma_v1,
        complete=complete,
        provenance_independent=provenance_independent,
        identifies=identifies,
        hconv=hconv,
    )
end

function clamp_sigma_identification_certificate(cert::ClampSigmaMeasurementCertificate)
    check = check_clamp_sigma_identification(cert)
    (
        kind=:ClampSigmaIdentification,
        ok=check.ok,
        lean_contracts=["body.clamp_sigma_identification"],
        julia_checkers=[:check_clamp_sigma_identification, :check_measured_hconv],
        numeric_assumptions=cert.numeric_assumptions,
        identification_assumption=cert.identification_assumption,
        profile_id=cert.profile_id,
        profile_sha256=cert.profile_sha256,
        provenance_independent=check.provenance_independent,
        identifies=check.identifies,
        hconv=check.hconv,
        julia_unverified_execution_boundary()...,
    )
end

function certified_clamp_sigma_identification(
    cert::ClampSigmaMeasurementCertificate,
    artifact_check::CertifiedArtifactCheck,
)
    payload = clamp_sigma_identification_certificate(cert)
    payload.ok || throw(ArgumentError("clamp sigma identification witness is invalid"))
    certified_artifact_envelope(payload, artifact_check)
end
