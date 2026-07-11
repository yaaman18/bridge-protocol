@enum InterventionMode begin
    normal_push
    normal_pull
    tangential_shear
    rotate
    contract
    expand
    local_growth_up
    local_growth_down
    obstacle_avoidance
end

@enum KernelParam begin
    kernel_mu
    kernel_sigma
    kernel_radius
end

@enum SensoryFeature begin
    boundary_sector
    radial_gradient
    normal_flux
    curvature_shape
    contact_obstacle
    nu_phi_contribution
end

const DEFAULT_INTERVENTION_MODES = (
    normal_push,
    normal_pull,
    tangential_shear,
    rotate,
    contract,
    expand,
    local_growth_up,
    local_growth_down,
    obstacle_avoidance,
)

const DEFAULT_KERNEL_PARAMS = (
    kernel_mu,
    kernel_sigma,
    kernel_radius,
)

const DEFAULT_SENSORY_FEATURES = (
    boundary_sector,
    radial_gradient,
    normal_flux,
    curvature_shape,
    contact_obstacle,
    nu_phi_contribution,
)

struct IndexedState{K,T<:Real}
    keys::Vector{K}
    values::Vector{T}

    function IndexedState(keys::AbstractVector{K}, values::AbstractVector{T}) where {K,T<:Real}
        length(keys) == length(values) ||
            throw(ArgumentError("keys and values must have the same length"))
        length(unique(keys)) == length(keys) ||
            throw(ArgumentError("keys must be unique"))
        new{K,T}(collect(keys), collect(values))
    end
end

const MotorState{T<:Real} = IndexedState{InterventionMode,T}
const KernelParamState{T<:Real} = IndexedState{KernelParam,T}
const SensoryState{T<:Real} = IndexedState{SensoryFeature,T}

intervention_modes() = collect(DEFAULT_INTERVENTION_MODES)
kernel_params() = collect(DEFAULT_KERNEL_PARAMS)
sensory_features() = collect(DEFAULT_SENSORY_FEATURES)

motor_state(values::AbstractVector{T};
    modes::AbstractVector{InterventionMode}=intervention_modes()) where {T<:Real} =
    IndexedState(modes, values)

kernel_param_state(values::AbstractVector{T};
    params::AbstractVector{KernelParam}=kernel_params()) where {T<:Real} =
    IndexedState(params, values)

sensory_state(values::AbstractVector{T};
    features::AbstractVector{SensoryFeature}=sensory_features()) where {T<:Real} =
    IndexedState(features, values)

state_vector(state::IndexedState) = copy(state.values)

function Base.getindex(state::IndexedState{K}, key::K) where {K}
    index = findfirst(==(key), state.keys)
    index === nothing && throw(KeyError(key))
    state.values[index]
end

struct BodyResponse{F}
    sigma::F
end

function respond(response::BodyResponse, state::IndexedState{InterventionMode})
    response.sigma(state)
end

(response::BodyResponse)(state::IndexedState{InterventionMode}) = respond(response, state)

body_response_domain_is_intervention(::BodyResponse) = true

struct ExternalSetPoint
    label::Symbol
end

struct SetPointDiagram{O,R}
    objects::Vector{O}
    reaches::R

    function SetPointDiagram(objects::AbstractVector{O}, reaches::R) where {O,R}
        !isempty(objects) || throw(ArgumentError("set-point diagram must contain objects"))
        length(unique(objects)) == length(objects) ||
            throw(ArgumentError("set-point diagram objects must be unique"))
        new{O,R}(collect(objects), reaches)
    end
end

struct EndogenousBodyResponse{F,G}
    sigma::F
    nu_phi_contribution::G
end

function respond(response::EndogenousBodyResponse, state::IndexedState{InterventionMode})
    response.sigma(state)
end

(response::EndogenousBodyResponse)(state::IndexedState{InterventionMode}) =
    respond(response, state)

endogenous_sigma_defined_without_external_setpoint(response::EndogenousBodyResponse) =
    response.sigma

has_external_setpoint_field(response) =
    :external_setpoint in fieldnames(typeof(response)) ||
    :set_point in fieldnames(typeof(response)) ||
    :target_pattern in fieldnames(typeof(response))

body_has_no_external_setpoint(response) = !has_external_setpoint_field(response)

function terminal_setpoints(diagram::SetPointDiagram)
    [
        candidate
        for candidate in diagram.objects
        if all(source -> diagram.reaches(source, candidate), diagram.objects)
    ]
end

has_terminal_setpoint(diagram::SetPointDiagram) =
    !isempty(terminal_setpoints(diagram))

check_m4_no_terminal_setpoint(diagram::SetPointDiagram) =
    !has_terminal_setpoint(diagram)

body_sigma_star_induced(alpha_rel, all_M, X) =
    sigma_star_induced(alpha_rel, all_M, X)

body_galois_conn_induced(alpha_rel, all_M, all_E) =
    check_K3(alpha_rel, all_M, powerset(all_E))

body_unit_induced(alpha_rel, all_M, N) =
    N ⊆ body_sigma_star_induced(alpha_rel, all_M, alpha_star(alpha_rel, N))

body_counit_induced(alpha_rel, all_M, X) =
    alpha_star(alpha_rel, body_sigma_star_induced(alpha_rel, all_M, X)) ⊆ X

body_jacobian(sigma, a) = sensitivity_tensor(sigma, a)

body_jacobian_adjoint(sigma, a) = transpose(body_jacobian(sigma, a))

check_body_dual_symmetry(sigma, a, x, y; tol=1e-10) =
    check_dual_symmetry(sigma, a, x, y; tol=tol)

function body_loop_operator(sigma, a)
    tensor = body_jacobian(sigma, a)
    transpose(tensor) * tensor
end

function check_body_tensor_requirements(sigma, a, x, y; tol=1e-10)
    tensor = body_jacobian(sigma, a)
    loop = transpose(tensor) * tensor
    (
        tensor=tensor,
        adjoint=transpose(tensor),
        loop=loop,
        rank=rank(tensor; atol=tol),
        nonzero_rank=rank(tensor; atol=tol) > 0,
        dual_symmetric=check_body_dual_symmetry(sigma, a, x, y; tol=tol),
        nontrivial_loop=rank(loop; atol=tol) > 0,
    )
end
