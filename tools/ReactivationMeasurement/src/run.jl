# start_run: the only supported way to start a run (RSB-001 §5). It needs the capability from
# `verify_substrate_registration`; this is a supported-API discipline, not a security boundary.

const _CASE_ID = r"^case-([0-9]+)\z"

"""
    start_run(token; runner_repo, run_id, out_dir) -> completion manifest

Re-reads the registered profile from the runner checkout, checks its digest and output schema,
writes the run-start record, measures every case in the registered order, and publishes the
completion manifest. `out_dir` must not exist yet and must lie outside the runner checkout
(files there would make the runner dirty).
"""
function start_run(token::VerifiedRegistration; runner_repo::AbstractString,
        run_id::AbstractString, out_dir::AbstractString)
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

    abs_out = abspath(out_dir)
    startswith(abs_out * "/", abspath(runner_repo) * "/") &&
        throw(ArgumentError("out_dir must lie outside the runner checkout"))
    ispath(abs_out) && throw(ArgumentError("out_dir already exists"))
    mkpath(joinpath(abs_out, "cases"))

    start_path = joinpath(abs_out, "run-start.toml")
    write_run_start_record(start_path, build_run_start_record(token; run_id))
    completed = String[]
    for id in token.case_ids
        m = match(_CASE_ID, id)
        m === nothing && throw(ArgumentError("unexpected case id $id"))
        record = measure_case(sub, proto, parse(Int, m.captures[1]))
        record["case_id"] = id
        validate_case_record(record, sub, proto)
        path = joinpath(abs_out, "cases", id * ".toml")
        ispath(path) && throw(ArgumentError("case record $id already exists"))
        open(path, "w") do io
            TOML.print(io, record; sorted=true)
        end
        push!(completed, id)
    end
    write_completion_manifest(joinpath(abs_out, "completion.toml"), read(start_path),
        completed, runner_state(runner_repo))
end
