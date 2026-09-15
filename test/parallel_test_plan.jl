const ERIEC_TEST_PLAN = [
    ("test_adjunction.jl", 1.0),
    ("test_interface_linearization.jl", 0.5),
    ("test_bridge_functor.jl", 0.5),
    ("test_viability_closure.jl", 0.5),
    ("test_layer_composition.jl", 0.5),
    ("test_closure.jl", 0.5),
    ("test_closure_audit.jl", 5.0),
    ("test_test_plan.jl", 0.5),
    ("test_hinge.jl", 0.5),
    ("test_dc.jl", 0.5),
    ("test_model_audit.jl", 3.0),
    ("test_model_audit_circuits.jl", 8.0),
    ("test_model_audit_symmetry.jl", 5.0),
    ("test_claim_audit.jl", 5.0),
    ("test_background_audit.jl", 8.0),
    ("test_measured_adjunction_separation.jl", 8.0),
    ("test_model_audit_viewer.jl", 8.0),
    ("test_countermodel_audit.jl", 10.0),
    ("test_implication_matrix_audit.jl", 12.0),
    ("test_assumption_suite_audit.jl", 12.0),
    ("test_constraint_overlay_audit.jl", 12.0),
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
    ("test_packet_review.jl", 0.5),
    ("test_g3c_evidence.jl", 0.5),
    ("test_cert_scope.jl", 0.5),
    ("test_checker_semantic_manifest.jl", 12.0),
    ("test_ledger_consistency.jl", 0.5),
    ("test_reference_models.jl", 0.5),
    ("test_wager.jl", 0.5),
    ("test_richness.jl", 0.5),
    ("test_generation.jl", 0.5),
    ("test_branch_novelty.jl", 0.5),
    ("test_temporal_dc.jl", 0.5),
    ("test_sigma_selection.jl", 1.0),
    ("test_sigma1_run.jl", 3.0),
    ("test_sigma1_diversity_audit.jl", 3.0),
    ("test_markers.jl", 0.5),
    ("test_umwelt_experiments.jl", 0.5),
    ("test_policy_topology.jl", 40.0),
    ("test_benchmarks_reports.jl", 4.0),
    ("test_observation_artifact.jl", 7.0),
    ("test_model_evaluation.jl", 65.0),
    ("test_orderreach_graded.jl", 41.0),
    ("test_decomp.jl", 0.5),
    ("test_grading.jl", 0.5),
    ("test_formal_julia_contract.jl", 7.0),
    ("test_v52_formal_statements.jl", 2.0),
    ("test_field_system.jl", 84.0),
    ("test_field_bridge.jl", 4.0),
    ("test_lenia_experiments.jl", 29.0),
    ("test_trm_python_bridge.jl", 1.0),
    ("test_visualization.jl", 3.0),
    ("test_cli.jl", 35.0),
    ("test_category_pipeline.jl", 6.0),
    ("test_open_categorical_layers.jl", 5.0),
]

"""Suites that spawn subprocesses or use shared Lake artifacts and must not
compete with CPU-heavy groups."""
const ERIEC_EXCLUSIVE_TEST_FILES = Set([
    "test_checker_semantic_manifest.jl",
    "test_cli.jl",
    "test_model_evaluation.jl",
    "test_v52_formal_statements.jl",
])

function validate_eriec_test_plan(test_dir::AbstractString=@__DIR__, plan=ERIEC_TEST_PLAN)
    files = first.(plan)
    length(files) == length(unique(files)) || error("ERIEC test plan contains duplicate files")
    missing_files = filter(file -> !isfile(joinpath(test_dir, file)), files)
    isempty(missing_files) || error("ERIEC test plan contains missing files: $(join(missing_files, ", "))")
    discovered = filter(file -> startswith(file, "test_") && endswith(file, ".jl") &&
        isfile(joinpath(test_dir, file)), readdir(test_dir))
    unregistered = sort!(setdiff(discovered, files))
    isempty(unregistered) || error("ERIEC test plan omits test files: $(join(unregistered, ", "))")
    true
end

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
