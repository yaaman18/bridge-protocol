struct ReferenceBenchmarkCase
    name::Symbol
    passed::Bool
    summary::NamedTuple
end

struct FourReferenceBenchmark
    cases::Vector{ReferenceBenchmarkCase}
end

benchmark_passed(benchmark::FourReferenceBenchmark) =
    all(case -> case.passed, benchmark.cases)

function run_reference_benchmarks(
    adapter::SigmaSystemAdapter,
    action::AbstractVector,
    dc_result::DCResult;
    direction::Union{AbstractVector,Nothing}=nothing,
    target::Real=1.0,
    eig_tol::Real=1e-6,
    fixed_tol::Real=1e-6,
    action_index::Integer=1,
    interoceptive_signal=[1.0],
)
    tensor = system_sensitivity_tensor(adapter, action)
    world = system_actuated_world(adapter, action; target=target, tol=eig_tol)
    selected_direction = direction === nothing ? world_fixed_direction(world) : direction
    bridge = DCWorldBridge(dc_result, world, selected_direction; fixed_tol=fixed_tol)

    computational = ReferenceBenchmarkCase(
        :computational_sanity,
        check_sigma_dimensions(adapter, action) &&
            all(isfinite, tensor) &&
            size(tensor, 2) == length(action),
        (tensor_size=size(tensor), action_length=length(action)),
    )

    adjunction = ReferenceBenchmarkCase(
        :adjunction_world_bridge,
        check_worlddc_bridge(bridge),
        (world_nontrivial=world_nontrivial(world), fixed_residual=bridge.fixed_residual),
    )

    blindsight_markers = FMMarkers(
        true,
        fm2_sensorimotor_integration(tensor, action_index),
        fm3_self_monitoring(Float64[]),
        fm4_world_participation(world, action_index),
    )
    blindsight = ReferenceBenchmarkCase(
        :blindsight_analog,
        classify_action_markers(blindsight_markers) == :blindsight_analog,
        (markers=blindsight_markers, classification=classify_action_markers(blindsight_markers)),
    )

    conscious_markers = FMMarkers(
        true,
        fm2_sensorimotor_integration(tensor, action_index),
        fm3_self_monitoring(interoceptive_signal),
        fm4_world_participation(world, action_index),
    )
    precariousness = ReferenceBenchmarkCase(
        :precariousness_slowing,
        critical_slowing_score(world; target=target) > 0 &&
            classify_action_markers(conscious_markers) == :conscious,
        (
            dominant_eigenvalue=dominant_world_eigenvalue(world),
            slowing_score=critical_slowing_score(world; target=target),
            classification=classify_action_markers(conscious_markers),
        ),
    )

    FourReferenceBenchmark([computational, adjunction, blindsight, precariousness])
end
