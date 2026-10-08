# start_run: the only supported way to start a run (RSB-001 §5). It needs the capability from
# `verify_substrate_registration`; this is a supported-API discipline, not a security boundary.
#
# RSB-GEN-001 §5: the criteria of a run are bound before anything is measured. They must be
# exactly the registered analysis plan's `recorded_criteria`; their labels are fixed in the
# run-start record; every case is judged by every criterion inside the same run. A response
# table of a registered profile is therefore never produced without its criteria fixed first.

const _CASE_ID = r"^case-([0-9]+)\z"

"""
    start_run(token; runner_repo, run_id, out_dir, criteria) -> completion manifest

Re-reads the registered profile and analysis plan from the runner checkout and checks their
digests and the output schema, refuses unless `criteria` match the plan's `recorded_criteria`,
writes the run-start record, measures and judges every case in the registered order, and
publishes the completion manifest. `out_dir` must not exist yet and must lie outside the
runner checkout (files there would make the runner dirty).
"""
function start_run(token::VerifiedRegistration; runner_repo::AbstractString,
        run_id::AbstractString, out_dir::AbstractString,
        criteria::AbstractVector=AbstractCriterion[])
    runner_repo = String(runner_repo)
    now = runner_state(runner_repo)
    for key in ("runner_commit", "runner_tree", "manifest_sha256", "julia_version")
        now[key] == token.runner[key] ||
            throw(ArgumentError("runner $key changed since verification"))
    end
    now["runner_dirty"] && throw(ArgumentError("runner checkout is dirty"))
    bytes = read(joinpath(runner_repo, token.profile_path))
    bytes2hex(sha256(bytes)) == token.profile_blob_sha256 ||
        throw(ArgumentError("profile bytes differ from the registered digest"))
    profile = validate_profile(bytes; version=token.profile_schema_validation_version)
    _check_output_schema(profile)
    sub, proto = substrate_from_profile(profile)

    plan_bytes = read(joinpath(runner_repo, token.analysis_plan_path))
    bytes2hex(sha256(plan_bytes)) == token.analysis_plan_digest ||
        throw(ArgumentError("analysis plan bytes differ from the registered digest"))
    all(c -> c isa AbstractCriterion, criteria) ||
        throw(ArgumentError("every criterion must be an AbstractCriterion"))
    analysis = validate_analysis_plan(plan_bytes; version=token.analysis_schema_validation_version)
    check_criteria_binding(analysis, criteria)
    # v2 plans bind each criterion to its package tree; v1 plans bind names only (RSB-BIND-001).
    bindings = haskey(analysis, "criterion_binding") ?
        check_criteria_implementation(analysis, criteria, runner_repo) : nothing
    structures = [declared_structure(sub, roles(sub), required_structure(c)) for c in criteria]

    abs_out = abspath(out_dir)
    startswith(abs_out * "/", abspath(runner_repo) * "/") &&
        throw(ArgumentError("out_dir must lie outside the runner checkout"))
    ispath(abs_out) && throw(ArgumentError("out_dir already exists"))
    # v2 plans: the engine decides the attempt from the runs root (RSB-RETRY-001 §2.1).
    attempt = token.analysis_schema_validation_version == "rsb-analysis-schema-v2" ?
        _attempt(token, abs_out, String(run_id)) : nothing
    mkpath(joinpath(abs_out, "cases"))
    for c in criteria
        mkpath(joinpath(abs_out, "criteria", criterion_id(c)))
    end
    seal_sha = ""
    if attempt !== nothing && attempt.number == 2
        seal_sha = _write_seal(joinpath(abs_out, "previous-attempt-seal.toml"), attempt.previous_dir)
    end

    start_path = joinpath(abs_out, "run-start.toml")
    start_record = attempt === nothing ?
        build_run_start_record(token; run_id, criteria=criterion_label.(criteria)) :
        build_run_start_record(token; run_id, criteria=criterion_label.(criteria),
            attempt=attempt.number, previous_attempt_run_id=attempt.previous_run_id,
            previous_attempt_seal_sha256=seal_sha,
            dependency_tree_oids=_dependency_trees(analysis, runner_repo))
    write_run_start_record(start_path, start_record)
    format = RSBCaseRecordV1()
    completed = String[]
    for id in token.case_ids
        m = match(_CASE_ID, id)
        m === nothing && throw(ArgumentError("unexpected case id $id"))
        table = measure_response(sub, proto, parse(Int, m.captures[1]))
        record = read_record(format, table, roles(sub))
        record["case_id"] = id
        validate_case_record(record, sub, proto)
        _write_new(joinpath(abs_out, "cases", id * ".toml"), record)
        for (c, structure) in zip(criteria, structures)
            result = criterion_result(c, id, record, structure)
            bindings === nothing || check_result_keys(result, bindings[criterion_id(c)])
            _write_new(joinpath(abs_out, "criteria", criterion_id(c), id * ".toml"), result)
        end
        push!(completed, id)
    end
    for c in criteria
        judged = sort!([replace(f, r"\.toml\z" => "")
            for f in readdir(joinpath(abs_out, "criteria", criterion_id(c)))])
        judged == sort(completed) ||
            throw(ArgumentError("criterion $(criterion_id(c)) did not judge every case"))
    end
    retry = attempt !== nothing && attempt.number == 2 ?
        retry_mismatches(attempt.previous_dir, joinpath(abs_out, "previous-attempt-seal.toml"), abs_out) :
        String[]
    write_completion_manifest(joinpath(abs_out, "completion.toml"), read(start_path),
        completed, runner_state(runner_repo); retry_mismatches=retry)
end

# ---------------------------------------------------------------------------------------------
# Attempts (RSB-PLAN-002 §6, RSB-RETRY-001). Only for runs under an analysis plan of schema v2.

const _MAX_ATTEMPTS = 2

# RSB-PLAN-002 §3.5: the trees a criterion depends on, recorded at run start (not bound).
_dependency_trees(analysis, runner_repo) = String[
    "$(b["criterion_id"])|$path|$(something(tree_oid_at(runner_repo, "HEAD", path), "absent"))"
    for b in analysis["criterion_binding"] for path in b["dependency_paths"]]

"""Run directories in the runs root (the parent of `out_dir`) that belong to this registration."""
function _prior_attempts(token, runs_root::AbstractString)
    isdir(runs_root) || return NamedTuple[]
    found = NamedTuple[]
    for dir in readdir(runs_root; join=true)
        start = joinpath(dir, "run-start.toml")
        isfile(start) || continue
        record = TOML.parsefile(start)
        get(record, "registration_id", nothing) == token.registration_id || continue
        completion = joinpath(dir, "completion.toml")
        status = isfile(completion) ? get(TOML.parsefile(completion), "status", "") : "absent"
        push!(found, (; dir, run_id=String(record["run_id"]), attempt=get(record, "attempt", 0), status))
    end
    found
end

function _attempt(token, abs_out::AbstractString, run_id::String)
    prior = _prior_attempts(token, dirname(abs_out))
    if isempty(prior)
        number, previous_dir, previous_run_id = 1, "", ""
    elseif length(prior) == 1
        p = only(prior)
        p.attempt == 1 || throw(ArgumentError("the existing run $(p.run_id) is not a first attempt"))
        p.status == "complete" &&
            throw(ArgumentError("the first attempt $(p.run_id) completed; a retry is not permitted"))
        number, previous_dir, previous_run_id = 2, p.dir, p.run_id
    else
        throw(ArgumentError("registration $(token.registration_id) has used its $_MAX_ATTEMPTS attempts in this runs root"))
    end
    endswith(run_id, "-attempt-$number") ||
        throw(ArgumentError("run_id must end with -attempt-$number for attempt $number"))
    (; number, previous_dir, previous_run_id)
end

"""Every file under `dir` (relative path => SHA-256), sorted by path. Reads bytes only."""
function seal_entries(dir::AbstractString)
    entries = Dict{String,String}()
    for (root, _, files) in walkdir(dir), f in files
        full = joinpath(root, f)
        entries[relpath(full, dir)] = bytes2hex(open(sha256, full))
    end
    entries
end

function _write_seal(path::AbstractString, previous_dir::AbstractString)
    data = Dict("sealed_dir" => basename(previous_dir), "files" => seal_entries(previous_dir))
    _write_new(path, data)
    bytes2hex(open(sha256, path))
end

"""
    retry_mismatches(previous_dir, seal_path, out_dir) -> Vector{String}

`previous_attempt_changed` when the first attempt's files no longer match the seal, and
`retry_overlap_mismatch` when a case record or criterion result of the first attempt differs from
the same file of the retry.
"""
function retry_mismatches(previous_dir::AbstractString, seal_path::AbstractString, out_dir::AbstractString)
    found = String[]
    sealed = TOML.parsefile(seal_path)["files"]
    seal_entries(previous_dir) == sealed || push!(found, "previous_attempt_changed")
    for (rel, digest) in sealed
        (startswith(rel, "cases/") || startswith(rel, "criteria/")) || continue
        mine = joinpath(out_dir, rel)
        if !isfile(mine) || bytes2hex(open(sha256, mine)) != digest
            push!(found, "retry_overlap_mismatch")
            break
        end
    end
    found
end

function _write_new(path::AbstractString, data::AbstractDict)
    ispath(path) && throw(ArgumentError("$(basename(path)) already exists"))
    open(path, "w") do io
        TOML.print(io, data; sorted=true)
    end
end
