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
    check_criteria_binding(validate_analysis_plan(plan_bytes), criteria)
    structures = [declared_structure(sub, roles(sub), required_structure(c)) for c in criteria]

    abs_out = abspath(out_dir)
    startswith(abs_out * "/", abspath(runner_repo) * "/") &&
        throw(ArgumentError("out_dir must lie outside the runner checkout"))
    ispath(abs_out) && throw(ArgumentError("out_dir already exists"))
    mkpath(joinpath(abs_out, "cases"))
    for c in criteria
        mkpath(joinpath(abs_out, "criteria", criterion_id(c)))
    end

    start_path = joinpath(abs_out, "run-start.toml")
    write_run_start_record(start_path,
        build_run_start_record(token; run_id, criteria=criterion_label.(criteria)))
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
    write_completion_manifest(joinpath(abs_out, "completion.toml"), read(start_path),
        completed, runner_state(runner_repo))
end

function _write_new(path::AbstractString, data::AbstractDict)
    ispath(path) && throw(ArgumentError("$(basename(path)) already exists"))
    open(path, "w") do io
        TOML.print(io, data; sorted=true)
    end
end
