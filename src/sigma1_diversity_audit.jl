"""Median of a finite diagnostic sample, with zero for an empty sample."""
function _sigma1_audit_median(values)
    ordered = sort!(Float64.(collect(values)))
    isempty(ordered) && return 0.0
    middle = length(ordered) ÷ 2
    isodd(length(ordered)) ? ordered[middle + 1] :
        (ordered[middle] + ordered[middle + 1]) / 2
end

"""Tukey-hinges IQR; the median is excluded from both halves for odd samples."""
function _sigma1_audit_iqr(values)
    ordered = sort!(Float64.(collect(values)))
    length(ordered) <= 1 && return 0.0
    half = length(ordered) ÷ 2
    lower = @view ordered[1:half]
    upper = @view ordered[(length(ordered) - half + 1):length(ordered)]
    _sigma1_audit_median(upper) - _sigma1_audit_median(lower)
end

function _sigma1_pairwise_distances(artifacts)
    distances = Float64[]
    for left in 1:(length(artifacts) - 1)
        for right in (left + 1):length(artifacts)
            distance = umwelt_relative_diff(
                artifacts[left],
                artifacts[right],
            ).projection_norm_diff
            isfinite(distance) ||
                error("same-size Σ1 projection distance must be finite")
            push!(distances, distance)
        end
    end
    distances
end

function _sigma1_size_diagnostics(individuals, artifacts, raw_reference_distances)
    sizes = sort!(unique(individual.size_label for individual in individuals))
    [begin
        indices = findall(individual -> individual.size_label == size, individuals)
        pairwise = _sigma1_pairwise_distances(artifacts[indices])
        cap_replaced = count(index -> !isfinite(raw_reference_distances[index]), indices)
        Dict(
            "size" => size,
            "individuals" => length(indices),
            "pairs" => length(pairwise),
            "pair_median" => _sigma1_audit_median(pairwise),
            "pair_iqr" => _sigma1_audit_iqr(pairwise),
            "pair_nonzero_fraction" => (isempty(pairwise) ? 0.0 :
                count(>(0.0), pairwise) / length(pairwise)),
            "cap_replaced" => cap_replaced,
            "cap_fraction" => cap_replaced / length(indices),
        )
    end for size in sizes]
end

"""Read-only, dimension-stratified audit of Σ1 diversity resolution.

The existing size-2 reference distance is used only to count non-finite values
that the certified adapter replaces by `M_f`. Resolution is measured separately
from all unordered same-size artifact pairs, so no replacement or new numeric
threshold is introduced by this diagnostic.
"""
function check_sigma1_diversity_resolution(
    individuals::AbstractVector{<:Sigma1Individual},
)
    isempty(individuals) && throw(ArgumentError("audit population must be nonempty"))
    before = sigma1_observe_trace.(individuals)
    artifacts = _sigma1_artifact.(individuals)
    reference = _sigma1_reference_artifact()
    raw_reference_distances = [
        umwelt_relative_diff(reference, artifact).projection_norm_diff
        for artifact in artifacts
    ]
    by_size = _sigma1_size_diagnostics(
        individuals,
        artifacts,
        raw_reference_distances,
    )
    after = sigma1_observe_trace.(individuals)
    cap_replaced = count(value -> !isfinite(value), raw_reference_distances)
    Dict(
        "pure" => before == after,
        "individuals" => length(individuals),
        "cap_replaced" => cap_replaced,
        "cap_fraction" => cap_replaced / length(individuals),
        "within_size_finite" => true,
        "by_size" => by_size,
    )
end

function _sigma1_archive_individuals(run)
    [candidate.individual for (_, candidate) in sort!(collect(run.archive.cells); by=first)]
end

function _sigma1_diversity_audit_plan(output_dir)
    Dict(
        "execute" => false,
        "replicates" => SIGMA1_REPLICATES,
        "seeds" => collect(SIGMA1_BASE_SEED:(SIGMA1_BASE_SEED + SIGMA1_REPLICATES - 1)),
        "output_dir" => String(output_dir),
        "changes_selection_kernel" => false,
    )
end

"""Reproduce the certified ten seeds and save a read-only diversity audit."""
function sigma1_run_diversity_audit(;
    execute::Bool=false,
    output_dir::AbstractString=joinpath("logs", "sigma1", "diversity-audit-20260720"),
)
    execute || return _sigma1_diversity_audit_plan(output_dir)
    _sigma1_require_approval()
    mkpath(output_dir)
    replicate_payloads = Dict{String,Any}[]
    for replicate in 0:(SIGMA1_REPLICATES - 1)
        population = sigma1_initial_population(replicate)
        result = sigma1_execute_replicate(replicate)
        result.valid || error("Σ1 diversity audit stopped by $(result.reason)")
        payload = Dict{String,Any}(
            "replicate" => replicate,
            "seed" => result.plan.seed,
            "initial" => check_sigma1_diversity_resolution(population),
            "selected" => check_sigma1_diversity_resolution(
                _sigma1_archive_individuals(result.selected),
            ),
            "null" => check_sigma1_diversity_resolution(
                _sigma1_archive_individuals(result.null),
            ),
            "selected_rejection_rate" => result.selected.rejection_rate,
            "null_rejection_rate" => result.null.rejection_rate,
        )
        push!(replicate_payloads, payload)
        _sigma1_write_toml(
            joinpath(output_dir, "rep$(replicate).toml"),
            payload,
        )
    end
    summary = Dict(
        "valid" => true,
        "replicates" => length(replicate_payloads),
        "seeds" => [payload["seed"] for payload in replicate_payloads],
        "pure" => all(
            payload -> payload["initial"]["pure"] &&
                payload["selected"]["pure"] && payload["null"]["pure"],
            replicate_payloads,
        ),
        "initial_cap_fraction" => [
            payload["initial"]["cap_fraction"] for payload in replicate_payloads
        ],
        "selected_cap_fraction" => [
            payload["selected"]["cap_fraction"] for payload in replicate_payloads
        ],
        "null_cap_fraction" => [
            payload["null"]["cap_fraction"] for payload in replicate_payloads
        ],
        "changes_selection_kernel" => false,
        "adds_numeric_threshold" => false,
        "generated_unix" => time(),
        "git_commit" => _sigma1_git_commit(),
    )
    _sigma1_write_toml(joinpath(output_dir, "summary.toml"), summary)
    summary
end
