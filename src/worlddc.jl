using LinearAlgebra

struct DCWorldBridge{V<:AbstractVector}
    dc_result::DCResult
    wld_result::Union{WldResult,Nothing}
    loop::AbstractMatrix
    direction::V
    act::Set
    fixed_residual::Float64
end

struct DCWorldHarnessResult{B,R,A,U}
    bridge::B
    reachability::R
    assumptions::A
    assumptions_used::U
    accepted::Bool
end

const WorldDCBridge = DCWorldBridge

worlddc_bridge_claim() = :consistency_harness
worlddc_bridge_is_equivalence_claim() = false

check_no_unconditional_worlddc(dc_holds::Bool, world_holds::Bool) =
    dc_holds != world_holds

check_forward_worlddc_counterexample(dc_result::DCResult, wld_result::WldResult) =
    is_DC(dc_result) && !world_nontrivial(wld_result)

check_backward_worlddc_counterexample(dc_result::DCResult, wld_result::WldResult) =
    !is_DC(dc_result) && world_nontrivial(wld_result)

check_no_unconditional_worlddc() =
    check_no_unconditional_worlddc(true, false) &&
    check_no_unconditional_worlddc(false, true)

function summarize_worlddc_bridge(bridge::DCWorldBridge)
    (
        claim=worlddc_bridge_claim(),
        is_equivalence_claim=worlddc_bridge_is_equivalence_claim(),
        is_dc=is_DC(bridge.dc_result),
        has_world_result=bridge.wld_result !== nothing,
        act_nonempty=!isempty(bridge.act),
        fixed_residual=bridge.fixed_residual,
    )
end

function world_fixed_direction(wld_result::WldResult; index::Integer=1)
    world_nontrivial(wld_result) ||
        throw(ArgumentError("world result has no fixed direction"))
    1 <= index <= size(wld_result.basis, 2) ||
        throw(BoundsError(wld_result.basis, (:, index)))
    direction = copy(wld_result.basis[:, index])
    direction_norm = norm(direction)
    direction_norm > 0 ||
        throw(ArgumentError("selected world direction must be nonzero"))
    direction / direction_norm
end

function _worlddc_fixed_residual(loop::AbstractMatrix, direction::AbstractVector)
    size(loop, 1) == size(loop, 2) ||
        throw(DimensionMismatch("world loop must be square"))
    length(direction) == size(loop, 2) ||
        throw(DimensionMismatch("direction length must match world loop domain dimension"))
    norm(loop * direction - direction)
end

function DCWorldBridge(
    dc_result::DCResult,
    loop::AbstractMatrix,
    direction::AbstractVector;
    nonzero_tol::Real=1e-10,
    fixed_tol::Real=1e-6,
)
    is_DC(dc_result) || throw(ArgumentError("dc_result must satisfy DC"))
    !isempty(dc_result.act) || throw(ArgumentError("dc_result must have nonempty act witness"))
    norm(direction) > nonzero_tol ||
        throw(ArgumentError("direction must be nonzero"))
    residual = _worlddc_fixed_residual(loop, direction)
    residual <= fixed_tol ||
        throw(ArgumentError("direction must be fixed by the world loop"))
    copied_direction = copy(direction)
    DCWorldBridge{typeof(copied_direction)}(
        dc_result,
        nothing,
        loop,
        copied_direction,
        copy(dc_result.act),
        Float64(residual),
    )
end

function dc_world_bridge(
    dc_result::DCResult,
    wld_result::WldResult;
    direction::Union{AbstractVector,Nothing}=nothing,
    nonzero_tol::Real=1e-10,
    fixed_tol::Real=1e-6,
)
    selected_direction = direction === nothing ? world_fixed_direction(wld_result) : direction
    DCWorldBridge(
        dc_result,
        wld_result,
        selected_direction;
        nonzero_tol=nonzero_tol,
        fixed_tol=fixed_tol,
    )
end

function DCWorldBridge(
    dc_result::DCResult,
    wld_result::WldResult,
    direction::AbstractVector;
    nonzero_tol::Real=1e-10,
    fixed_tol::Real=1e-6,
)
    bridge = DCWorldBridge(
        dc_result,
        wld_result.loop,
        direction;
        nonzero_tol=nonzero_tol,
        fixed_tol=fixed_tol,
    )
    DCWorldBridge{typeof(bridge.direction)}(
        bridge.dc_result,
        wld_result,
        bridge.loop,
        bridge.direction,
        bridge.act,
        bridge.fixed_residual,
    )
end

check_worlddc_bridge(::DCWorldBridge)::Bool = true

function check_worlddc_bridge(
    dc_result::DCResult,
    loop::AbstractMatrix,
    direction::AbstractVector;
    nonzero_tol::Real=1e-10,
    fixed_tol::Real=1e-6,
)::Bool
    try
        DCWorldBridge(
            dc_result,
            loop,
            direction;
            nonzero_tol=nonzero_tol,
            fixed_tol=fixed_tol,
        )
        true
    catch err
        err isa ArgumentError || err isa DimensionMismatch || rethrow()
        false
    end
end

function check_worlddc_bridge(
    dc_result::DCResult,
    wld_result::WldResult,
    direction::AbstractVector;
    nonzero_tol::Real=1e-10,
    fixed_tol::Real=1e-6,
)::Bool
    check_worlddc_bridge(
        dc_result,
        wld_result.loop,
        direction;
        nonzero_tol=nonzero_tol,
        fixed_tol=fixed_tol,
    )
end

check_worlddc_bridge(dc_result::DCResult, wld_result::WldResult)::Bool =
    is_DC(dc_result) && world_nontrivial(wld_result)

function dc_world_harness(
    dc_result::DCResult,
    wld_result::WldResult;
    direction::Union{AbstractVector,Nothing}=nothing,
    reachability=nothing,
    require_reachable::Bool=false,
    fixed_tol::Real=1e-6,
)
    bridge = dc_world_bridge(
        dc_result,
        wld_result;
        direction=direction,
        fixed_tol=fixed_tol,
    )
    reachable_ok = reachability === nothing || !require_reachable ||
        getproperty(reachability, :reachable)
    assumptions = (
        claim=worlddc_bridge_claim(),
        requires_dc=true,
        requires_nonzero_fixed_direction=true,
        requires_reachability=require_reachable,
        equivalence_claim=false,
    )
    assumptions_used = Symbol[
        :dc_result,
        :wld_nontrivial,
        :nonzero_fixed_direction,
    ]
    require_reachable && push!(assumptions_used, :ordered_reachability)
    DCWorldHarnessResult(
        bridge,
        reachability,
        assumptions,
        assumptions_used,
        check_worlddc_bridge(bridge) && reachable_ok,
    )
end
