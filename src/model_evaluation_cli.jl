const MODEL_EVALUATION_CLI_USAGE = """
Usage:
  eriec-model-evaluation.jl run --model PATH [--root PATH] [--evaluation-id ID] [--counterexample-candidate]
  eriec-model-evaluation.jl list [--root PATH] [--vp-id ID] [--contract-id ID] [--outcome pass|reject|error] [--counterexample-candidates]
  eriec-model-evaluation.jl audit [--root PATH] [--evaluation-id ID]
  eriec-model-evaluation.jl draft --evaluation-id ID [--root PATH]
  eriec-model-evaluation.jl draft-list [--root PATH]
  eriec-model-evaluation.jl draft-audit [--root PATH] [--evaluation-id ID]
"""

function _model_evaluation_cli_options(args::Vector{String}, value_options, flag_options)
    values = Dict{String,String}()
    flags = Set{String}()
    index = 1
    while index <= length(args)
        option = args[index]
        startswith(option, "--") || throw(ArgumentError("unexpected argument: $option"))
        if option in flag_options
            option in flags && throw(ArgumentError("duplicate option: $option"))
            push!(flags, option)
            index += 1
        elseif option in value_options
            haskey(values, option) && throw(ArgumentError("duplicate option: $option"))
            index < length(args) || throw(ArgumentError("$option requires a value"))
            value = args[index + 1]
            startswith(value, "--") && throw(ArgumentError("$option requires a value"))
            isempty(value) && throw(ArgumentError("$option requires a nonempty value"))
            values[option] = value
            index += 2
        else
            throw(ArgumentError("unknown option: $option"))
        end
    end
    (; values, flags)
end

_model_evaluation_cli_json(io::IO, payload) =
    println(io, String(JSON3.write(payload)))

function _model_evaluation_cli_root(value::AbstractString; create::Bool=false)
    root = abspath(value)
    create && mkpath(root)
    ispath(root) ? realpath(root) : root
end

function _model_evaluation_cli_artifact(path::AbstractString, root::AbstractString)
    actual = realpath(path)
    canonical_root = realpath(root)
    startswith(actual, canonical_root * string(Base.Filesystem.path_separator)) ||
        throw(ArgumentError("created artifact escaped the evidence root"))
    relpath(actual, canonical_root)
end

function _model_evaluation_cli_run(
    args::Vector{String},
    project_root::AbstractString,
    out::IO,
)
    options = _model_evaluation_cli_options(
        args,
        Set(["--model", "--root", "--evaluation-id"]),
        Set(["--counterexample-candidate"]),
    )
    haskey(options.values, "--model") || throw(ArgumentError("run requires --model"))
    evidence_root = _model_evaluation_cli_root(
        get(options.values, "--root", project_root);
        create=true,
    )
    result = run_m4_model_evaluation(
        project_root,
        options.values["--model"];
        output_root=evidence_root,
        model_root=evidence_root,
        evaluation_id=get(options.values, "--evaluation-id", nothing),
        claim_relation="--counterexample-candidate" in options.flags ?
            :counterexample_candidate : :observation_only,
    )
    _model_evaluation_cli_json(out, (
        kind=:model_evaluation_run,
        evaluation_id=result.record.evaluation_id,
        outcome=result.record.outcome,
        claim_relation=result.record.claim_relation,
        model_fingerprint=result.record.model_fingerprint,
        artifact=_model_evaluation_cli_artifact(result.path, evidence_root),
        claim_status=:not_a_claim,
        phenomenal_claim=:not_certified,
    ))
    result.record.outcome == :error ? 1 : 0
end

function _model_evaluation_cli_list(
    args::Vector{String},
    project_root::AbstractString,
    out::IO,
)
    options = _model_evaluation_cli_options(
        args,
        Set(["--root", "--vp-id", "--contract-id", "--outcome"]),
        Set(["--counterexample-candidates"]),
    )
    evidence_root = _model_evaluation_cli_root(
        get(options.values, "--root", project_root),
    )
    outcome = if haskey(options.values, "--outcome")
        parsed = Symbol(options.values["--outcome"])
        parsed in _MODEL_EVALUATION_OUTCOMES ||
            throw(ArgumentError("--outcome must be pass, reject, or error"))
        parsed
    else
        nothing
    end
    entries = list_model_evaluations(
        evidence_root;
        project_root=project_root,
        vp_id=get(options.values, "--vp-id", nothing),
        contract_id=get(options.values, "--contract-id", nothing),
        outcome=outcome,
        counterexample_candidates="--counterexample-candidates" in options.flags,
    )
    _model_evaluation_cli_json(out, (
        kind=:model_evaluation_list,
        count=length(entries),
        entries=entries,
    ))
    0
end

function _model_evaluation_cli_audit(
    args::Vector{String},
    project_root::AbstractString,
    out::IO,
)
    options = _model_evaluation_cli_options(
        args,
        Set(["--root", "--evaluation-id"]),
        Set{String}(),
    )
    evidence_root = _model_evaluation_cli_root(
        get(options.values, "--root", project_root),
    )
    result = if haskey(options.values, "--evaluation-id")
        audit_model_evaluation(
            evidence_root,
            options.values["--evaluation-id"];
            project_root=project_root,
        )
    else
        audit_model_evaluations(evidence_root; project_root=project_root)
    end
    _model_evaluation_cli_json(out, result)
    result.ok ? 0 : 1
end

function _model_evaluation_cli_draft(
    args::Vector{String},
    project_root::AbstractString,
    out::IO,
)
    options = _model_evaluation_cli_options(
        args,
        Set(["--root", "--evaluation-id"]),
        Set{String}(),
    )
    haskey(options.values, "--evaluation-id") ||
        throw(ArgumentError("draft requires --evaluation-id"))
    evidence_root = _model_evaluation_cli_root(
        get(options.values, "--root", project_root),
    )
    path = write_counterexample_draft_packet(
        evidence_root,
        options.values["--evaluation-id"];
        project_root=project_root,
    )
    _model_evaluation_cli_json(out, (
        kind=:counterexample_claim_draft_created,
        evaluation_id=options.values["--evaluation-id"],
        artifact=_model_evaluation_cli_artifact(path, evidence_root),
        automatic_promotion=false,
        claim_status=:draft_not_a_claim,
    ))
    0
end


function _model_evaluation_cli_draft_list(
    args::Vector{String},
    project_root::AbstractString,
    out::IO,
)
    options = _model_evaluation_cli_options(
        args,
        Set(["--root"]),
        Set{String}(),
    )
    evidence_root = _model_evaluation_cli_root(
        get(options.values, "--root", project_root),
    )
    entries = list_counterexample_drafts(
        evidence_root;
        project_root=project_root,
    )
    _model_evaluation_cli_json(out, (
        kind=:counterexample_draft_list,
        count=length(entries),
        entries,
    ))
    0
end

function _model_evaluation_cli_draft_audit(
    args::Vector{String},
    project_root::AbstractString,
    out::IO,
)
    options = _model_evaluation_cli_options(
        args,
        Set(["--root", "--evaluation-id"]),
        Set{String}(),
    )
    evidence_root = _model_evaluation_cli_root(
        get(options.values, "--root", project_root),
    )
    result = if haskey(options.values, "--evaluation-id")
        audit_counterexample_draft(
            evidence_root,
            options.values["--evaluation-id"];
            project_root=project_root,
        )
    else
        audit_counterexample_drafts(evidence_root; project_root=project_root)
    end
    _model_evaluation_cli_json(out, result)
    result.ok ? 0 : 1
end

"""Run the dedicated model-evaluation CLI; returns a process exit code."""
function model_evaluation_cli(
    args::AbstractVector{<:AbstractString};
    project_root::AbstractString=dirname(@__DIR__),
    out::IO=stdout,
    err::IO=stderr,
)
    normalized = String[String(arg) for arg in args]
    canonical_project_root = _model_evaluation_cli_root(project_root)
    if isempty(normalized)
        _model_evaluation_cli_json(err, (
            kind=:model_evaluation_cli_error,
            error="a command is required",
            usage=MODEL_EVALUATION_CLI_USAGE,
        ))
        return 2
    end
    if normalized == ["--help"] || normalized == ["-h"]
        print(out, MODEL_EVALUATION_CLI_USAGE)
        return 0
    end
    command, rest = first(normalized), normalized[2:end]
    if rest == ["--help"] || rest == ["-h"]
        command in ("run", "list", "audit", "draft", "draft-list", "draft-audit") || begin
            _model_evaluation_cli_json(err, (
                kind=:model_evaluation_cli_error,
                error="unknown command: $command",
            ))
            return 2
        end
        print(out, MODEL_EVALUATION_CLI_USAGE)
        return 0
    end
    try
        command == "run" && return _model_evaluation_cli_run(rest, canonical_project_root, out)
        command == "list" && return _model_evaluation_cli_list(rest, canonical_project_root, out)
        command == "audit" && return _model_evaluation_cli_audit(rest, canonical_project_root, out)
        command == "draft" && return _model_evaluation_cli_draft(rest, canonical_project_root, out)
        command == "draft-list" &&
            return _model_evaluation_cli_draft_list(rest, canonical_project_root, out)
        command == "draft-audit" &&
            return _model_evaluation_cli_draft_audit(rest, canonical_project_root, out)
        throw(ArgumentError("unknown command: $command"))
    catch caught
        if caught isa ArgumentError
            _model_evaluation_cli_json(err, (
                kind=:model_evaluation_cli_error,
                error=_model_evaluation_showerror(caught),
            ))
            return 2
        end
        _model_evaluation_cli_json(err, (
            kind=:model_evaluation_cli_error,
            error=_model_evaluation_showerror(caught),
        ))
        return 1
    end
end
