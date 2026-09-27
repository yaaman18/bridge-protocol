# Run-start record and completion-manifest template (RSB-001 §6).
#
# The run-start record is the authority; the completion manifest refers to it by the SHA-256
# of its written bytes and re-checks the runner. Neither schema has a field for relations,
# trajectories or DC conditions, so such values cannot be recorded here (RSB-001 §8(3)).

const RECORD_SCHEMA_VERSION = 1

const RUN_START_SCHEMA = Dict{String,Any}(
    "record_kind" => field(:string; allowed=["rsb_run_start"]),
    "record_schema_version" => field(:int; allowed=[RECORD_SCHEMA_VERSION]),
    "run_id" => field(:id),
    "registration_id" => field(:id),
    "registration_commit" => field(:hex40),
    "profile_commit" => field(:hex40),
    "profile_id" => field(:id),
    "profile_blob_sha256" => field(:hex64),
    "analysis_plan_digest" => field(:hex64),
    "remote_url" => field(:string),
    "remote_ref" => field(:string),
    "observed_remote_oid" => field(:hex40),
    "preregistration_strength" => field(:string; allowed=["full", "post_results_replacement"]),
    "profile_schema_validation_version" => field(:string; allowed=PROFILE_SCHEMA_VERSIONS),
    "analysis_schema_validation_version" => field(:string; allowed=[ANALYSIS_SCHEMA_VALIDATION_VERSION]),
    "runner_commit" => field(:hex40),
    "runner_tree" => field(:hex40),
    "runner_dirty" => field(:bool; allowed=[false]),
    "manifest_sha256" => field(:hex64),
    "julia_version" => field(:string),
    "case_digest_version" => field(:string; allowed=[CASE_DIGEST_VERSION]),
    "case_count" => field(:int),
    "case_ids" => field(:string_list),
    "case_digest" => field(:hex64),
    "phenomenal_claim" => field(:string; allowed=["not_certified"]),
)

const COMPLETION_MISMATCH_CODES = ["case_count", "case_ids_ordered", "case_digest",
    "runner_commit", "runner_tree", "manifest_sha256", "julia_version", "runner_dirty"]

const COMPLETION_SCHEMA = Dict{String,Any}(
    "record_kind" => field(:string; allowed=["rsb_completion_manifest"]),
    "record_schema_version" => field(:int; allowed=[RECORD_SCHEMA_VERSION]),
    "run_id" => field(:id),
    "run_start_record_digest" => field(:hex64),
    "status" => field(:string; allowed=["complete", "incomplete"]),
    "mismatches" => field(:string_list),
    "completed_case_count" => field(:int),
    "completed_case_digest" => field(:hex64),
    "phenomenal_claim" => field(:string; allowed=["not_certified"]),
)

"""Build the run-start record. Requires the verification capability."""
function build_run_start_record(token::VerifiedRegistration; run_id::AbstractString)
    r = token.runner
    Dict{String,Any}(
        "record_kind" => "rsb_run_start",
        "record_schema_version" => RECORD_SCHEMA_VERSION,
        "run_id" => String(run_id),
        "registration_id" => token.registration_id,
        "registration_commit" => token.registration_commit,
        "profile_commit" => token.profile_commit,
        "profile_id" => token.profile_id,
        "profile_blob_sha256" => token.profile_blob_sha256,
        "analysis_plan_digest" => token.analysis_plan_digest,
        "remote_url" => token.remote_url,
        "remote_ref" => token.remote_ref,
        "observed_remote_oid" => token.observed_remote_oid,
        "preregistration_strength" => token.preregistration_strength,
        "profile_schema_validation_version" => token.profile_schema_validation_version,
        "analysis_schema_validation_version" => token.analysis_schema_validation_version,
        "runner_commit" => r["runner_commit"],
        "runner_tree" => r["runner_tree"],
        "runner_dirty" => r["runner_dirty"],
        "manifest_sha256" => r["manifest_sha256"],
        "julia_version" => r["julia_version"],
        "case_digest_version" => CASE_DIGEST_VERSION,
        "case_count" => length(token.case_ids),
        "case_ids" => copy(token.case_ids),
        "case_digest" => case_digest(token.case_ids),
        "phenomenal_claim" => "not_certified",
    )
end

function validate_run_start_record(record::AbstractDict)
    errors = _check!(String[], record, RUN_START_SCHEMA, "")
    if isempty(errors)
        ids = record["case_ids"]
        length(ids) == record["case_count"] || push!(errors, "case_count differs from case_ids")
        allunique(ids) || push!(errors, "case_ids must be unique")
        try
            case_digest(ids) == record["case_digest"] || push!(errors, "case_digest does not match case_ids")
        catch e
            e isa ArgumentError || rethrow()
            push!(errors, sprint(showerror, e))
        end
    end
    isempty(errors) || throw(SchemaViolation(errors))
    true
end

_toml_bytes(d::AbstractDict) = Vector{UInt8}(sprint(io -> TOML.print(io, d; sorted=true)))

# Publish `bytes` at `path` only if nothing is there yet. The content is written to a
# temporary file first and then hard-linked into place; `link` fails if `path` exists, so
# readers see either no file or the complete file.
function _write_new_file(path::AbstractString, bytes::Vector{UInt8})
    tmp = path * ".tmp-" * string(getpid()) * "-" * string(time_ns())
    try
        write(tmp, bytes)
        try
            hardlink(tmp, path)
        catch e
            ispath(path) && throw(ArgumentError("refusing to overwrite $path"))
            rethrow()
        end
    finally
        rm(tmp; force=true)
    end
    path
end

"""Validate and write the run-start record; returns the SHA-256 of the written bytes."""
function write_run_start_record(path::AbstractString, record::AbstractDict)
    validate_run_start_record(record)
    bytes = _toml_bytes(record)
    _write_new_file(path, bytes)
    _sha(bytes)
end

"""
    completion_manifest(start_record_bytes, completed_case_ids, runner_now)

`status = "complete"` only when the completed case list equals the recorded ordered list and
the runner commit, tree, cleanliness, Manifest digest and Julia version are unchanged.
Completed case IDs must satisfy the case-ID character set; otherwise `ArgumentError`.
"""
function completion_manifest(start_record_bytes::AbstractVector{UInt8},
        completed_case_ids::AbstractVector{<:AbstractString}, runner_now::AbstractDict)
    start = _parse_toml(start_record_bytes, "run-start record")
    validate_run_start_record(start)
    mismatches = String[]
    completed = String.(completed_case_ids)
    length(completed) == start["case_count"] || push!(mismatches, "case_count")
    completed == start["case_ids"] || push!(mismatches, "case_ids_ordered")
    completed_digest = case_digest(completed)
    completed_digest == start["case_digest"] || push!(mismatches, "case_digest")
    for key in ("runner_commit", "runner_tree", "manifest_sha256", "julia_version")
        get(runner_now, key, nothing) == start[key] || push!(mismatches, key)
    end
    get(runner_now, "runner_dirty", true) === false || push!(mismatches, "runner_dirty")
    Dict{String,Any}(
        "record_kind" => "rsb_completion_manifest",
        "record_schema_version" => RECORD_SCHEMA_VERSION,
        "run_id" => start["run_id"],
        "run_start_record_digest" => _sha(start_record_bytes),
        "status" => isempty(mismatches) ? "complete" : "incomplete",
        "mismatches" => mismatches,
        "completed_case_count" => length(completed),
        "completed_case_digest" => completed_digest,
        "phenomenal_claim" => "not_certified",
    )
end

function validate_completion_manifest(manifest::AbstractDict)
    errors = _check!(String[], manifest, COMPLETION_SCHEMA, "")
    if isempty(errors)
        (manifest["status"] == "complete") == isempty(manifest["mismatches"]) ||
            push!(errors, "status must be complete exactly when there are no mismatches")
        all(m -> m in COMPLETION_MISMATCH_CODES, manifest["mismatches"]) ||
            push!(errors, "mismatches must use the fixed mismatch codes")
    end
    isempty(errors) || throw(SchemaViolation(errors))
    true
end

"""
    write_completion_manifest(path, start_record_bytes, completed_case_ids, runner_now)

Recomputes the manifest from the run-start record and the current runner state, then
publishes it without overwriting. The status is never taken from the caller.
"""
function write_completion_manifest(path::AbstractString, start_record_bytes::AbstractVector{UInt8},
        completed_case_ids::AbstractVector{<:AbstractString}, runner_now::AbstractDict)
    manifest = completion_manifest(start_record_bytes, completed_case_ids, runner_now)
    validate_completion_manifest(manifest)
    _write_new_file(path, _toml_bytes(manifest))
    manifest
end
