const ERIEC_TEST_PLAN = [
    ("test_adjunction.jl", 1.0),
    ("test_interface_linearization.jl", 0.5),
    ("test_bridge_functor.jl", 0.5),
    ("test_viability_closure.jl", 0.5),
    ("test_layer_composition.jl", 0.5),
    ("test_closure.jl", 0.5),
    ("test_hinge.jl", 0.5),
    ("test_dc.jl", 0.5),
    ("checkpoints.jl", 1.5),
    ("test_sensitivity.jl", 4.0),
    ("test_value.jl", 1.0),
    ("test_weighted.jl", 1.0),
    ("test_body.jl", 16.0),
    ("test_guard.jl", 0.5),
    ("test_world.jl", 8.0),
    ("test_worlddc.jl", 8.0),
    ("test_consume.jl", 0.5),
    ("test_observation.jl", 0.5),
    ("test_system_adapter.jl", 3.0),
    ("test_toy_systems.jl", 5.0),
    ("test_reachability.jl", 0.5),
    ("test_acceptance.jl", 0.5),
    ("test_slowing.jl", 0.5),
    ("test_dynamics.jl", 0.5),
    ("test_invariance.jl", 0.5),
    ("test_lean_architecture.jl", 0.5),
    ("test_claim_ledger.jl", 0.5),
    ("test_reference_models.jl", 0.5),
    ("test_wager.jl", 0.5),
    ("test_richness.jl", 0.5),
    ("test_generation.jl", 0.5),
    ("test_temporal_dc.jl", 0.5),
    ("test_sigma_selection.jl", 1.0),
    ("test_sigma1_run.jl", 3.0),
    ("test_markers.jl", 0.5),
    ("test_umwelt_experiments.jl", 0.5),
    ("test_policy_topology.jl", 40.0),
    ("test_benchmarks_reports.jl", 4.0),
    ("test_observation_artifact.jl", 7.0),
    ("test_orderreach_graded.jl", 41.0),
    ("test_decomp.jl", 0.5),
    ("test_grading.jl", 0.5),
    ("test_formal_julia_contract.jl", 7.0),
    ("test_v52_formal_statements.jl", 2.0),
    ("test_field_system.jl", 84.0),
    ("test_lenia_experiments.jl", 29.0),
    ("test_trm_python_bridge.jl", 1.0),
    ("test_visualization.jl", 3.0),
    ("test_cli.jl", 35.0),
    ("test_category_pipeline.jl", 6.0),
    ("test_open_categorical_layers.jl", 5.0),
]

"""Suites that spawn subprocesses or use shared Lake artifacts and must not
compete with CPU-heavy groups."""
const ERIEC_EXCLUSIVE_TEST_FILES = Set(["test_cli.jl", "test_v52_formal_statements.jl"])

function eriec_test_groups(job_count::Integer)
    parallel_plan = filter(entry -> first(entry) ∉ ERIEC_EXCLUSIVE_TEST_FILES, ERIEC_TEST_PLAN)
    1 <= job_count <= length(parallel_plan) ||
        throw(ArgumentError("job_count must be between 1 and $(length(parallel_plan))"))

    groups = [String[] for _ in 1:job_count]
    loads = zeros(Float64, job_count)
    indexed_plan = collect(enumerate(parallel_plan))

    # Longest-processing-time scheduling keeps the slow numerical suites apart.
    sort!(indexed_plan; by=entry -> (-entry[2][2], entry[1]))
    for (_, (file, estimated_seconds)) in indexed_plan
        group = argmin(loads)
        push!(groups[group], file)
        loads[group] += estimated_seconds
    end

    groups, loads
end
