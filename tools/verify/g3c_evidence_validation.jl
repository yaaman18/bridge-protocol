module G3CEvidenceValidation

using JSON3
using SHA
using TOML

export G3CValidationCheck,
    g3c_evidence_checks,
    g3c_evidence_text_checks,
    g3c_transition_checks,
    validate_g3c_evidence,
    validate_g3c_transition

struct G3CValidationCheck
    code::String
    ok::Bool
    subject::String
    detail::String
end

default_project_root() = normpath(joinpath(@__DIR__, "..", ".."))

function add_check!(checks, code, ok, subject, detail)
    push!(checks, G3CValidationCheck(code, ok, subject, detail))
end

failures(checks) = filter(check -> !check.ok, checks)

function git_bytes(root::AbstractString, arguments::AbstractString...)
    read(Cmd(vcat(["git", "-C", root], collect(arguments))))
end

git_text(root::AbstractString, arguments::AbstractString...) =
    String(git_bytes(root, arguments...))

is_full_oid(value) = value isa AbstractString &&
    occursin(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$", value)

function resolve_commit(root::AbstractString, revision)
    is_full_oid(revision) || return nothing
    try
        resolved = strip(git_text(root, "rev-parse", "--verify", "$(revision)^{commit}"))
        return resolved == revision ? resolved : nothing
    catch
        return nothing
    end
end

function canonical_gate_log_path(relative_path)
    relative_path isa AbstractString || return false
    isabspath(relative_path) && return false
    occursin('\n', relative_path) && return false
    occursin('\r', relative_path) && return false
    parts = split(relative_path, '/')
    length(parts) >= 4 || return false
    parts[1:2] == ["logs", "gates"] || return false
    all(part -> !isempty(part) && part != "." && part != "..", parts)
end

function nul_records(bytes::Vector{UInt8})
    records = Vector{Vector{UInt8}}()
    start = firstindex(bytes)
    for index in eachindex(bytes)
        bytes[index] == 0x00 || continue
        index > start && push!(records, copy(bytes[start:(index - 1)]))
        start = index + 1
    end
    start <= lastindex(bytes) && push!(records, copy(bytes[start:end]))
    records
end

function blob_digest(bytes::Vector{UInt8}, object_format::AbstractString)
    header = Vector{UInt8}(codeunits("blob $(length(bytes))\0"))
    payload = vcat(header, bytes)
    object_format == "sha1" && return bytes2hex(SHA.sha1(payload))
    object_format == "sha256" && return bytes2hex(SHA.sha256(payload))
    error("unsupported Git object format: $object_format")
end

function input_digest_for_commit(root::AbstractString, commit::AbstractString)
    manifest_text = git_text(
        root,
        "show",
        "$commit:specs/checker-semantic-manifest.toml",
    )
    manifest = TOML.parse(manifest_text)
    basis_logs = Set{String}()
    for row in get(manifest, "contract", Any[])
        basis_log = String(get(row, "basis_log", ""))
        isempty(basis_log) && continue
        parts = split(basis_log, '/')
        startswith(basis_log, "logs/") || error("basis_log must be below logs/")
        all(part -> !isempty(part) && part != "." && part != "..", parts) ||
            error("basis_log is not canonical")
        push!(basis_logs, basis_log)
    end

    projection = UInt8[]
    for entry in nul_records(git_bytes(root, "ls-tree", "-rz", "--full-tree", commit))
        tab = findfirst(==(UInt8('\t')), entry)
        tab === nothing && error("malformed git ls-tree record")
        relative_path = String(entry[(tab + 1):end])
        startswith(relative_path, "logs/") && relative_path ∉ basis_logs && continue
        append!(projection, entry)
        push!(projection, 0x00)
    end
    object_format = strip(git_text(root, "rev-parse", "--show-object-format"))
    blob_digest(projection, object_format), object_format
end

function committed_path_dependencies(root::AbstractString, commit::AbstractString)
    manifest = JSON3.read(git_text(root, "show", "$commit:lake-manifest.json"))
    Set(
        String(package.dir)
        for package in manifest.packages
        if String(package.type) == "path"
    )
end

function unique_value!(checks, lines, prefix, subject=prefix)
    matches = filter(line -> startswith(line, prefix), lines)
    add_check!(
        checks,
        "G3C_SINGLE_VALUE",
        length(matches) == 1,
        subject,
        "the field must occur exactly once",
    )
    length(matches) == 1 || return nothing
    matches[1][(length(prefix) + 1):end]
end

function ordered_once(lines, markers)
    indices = Int[]
    for marker in markers
        found = findall(==(marker), lines)
        length(found) == 1 || return false
        push!(indices, only(found))
    end
    issorted(indices) && length(unique(indices)) == length(indices)
end

function parse_dependency_row(line::AbstractString)
    matched = match(
        r"^path=(\.\./[A-Za-z0-9._-]+) origin=(.+) head=([0-9a-f]+) index_tree=([0-9a-f]+) cache_mode=([A-Za-z0-9_]+) shared_mutable=false$",
        line,
    )
    matched === nothing && return nothing
    (
        path=matched.captures[1],
        origin=matched.captures[2],
        head=matched.captures[3],
        index_tree=matched.captures[4],
        cache_mode=matched.captures[5],
    )
end

function check_path_dependencies!(checks, lines, root, commit, object_format)
    begin_indices = findall(==("G3C_PATH_DEPENDENCIES_BEGIN"), lines)
    end_indices = findall(==("G3C_PATH_DEPENDENCIES_END"), lines)
    valid_section = length(begin_indices) == 1 && length(end_indices) == 1 &&
        only(begin_indices) < only(end_indices)
    add_check!(
        checks,
        "G3C_PATH_DEPENDENCY_SECTION",
        valid_section,
        "path_dependencies",
        "dependency section delimiters must occur once and in order",
    )
    valid_section || return

    rows = lines[(only(begin_indices) + 1):(only(end_indices) - 1)]
    parsed_rows = [parse_dependency_row(row) for row in rows]
    add_check!(
        checks,
        "G3C_PATH_DEPENDENCY_ROW",
        all(row -> row !== nothing, parsed_rows),
        "path_dependencies",
        "every dependency row must use the canonical v2 format",
    )
    all(row -> row !== nothing, parsed_rows) || return
    dependencies = [row::NamedTuple for row in parsed_rows]
    logged_paths = [dependency.path for dependency in dependencies]
    expected_paths = try
        committed_path_dependencies(root, commit)
    catch
        Set{String}()
    end
    add_check!(
        checks,
        "G3C_PATH_DEPENDENCY_SET",
        length(logged_paths) == length(unique(logged_paths)) &&
            Set(logged_paths) == expected_paths,
        "path_dependencies",
        "logged path dependencies must exactly match the committed Lake manifest",
    )

    allowed_cache_modes = Set([
        "copy_on_write_macos",
        "copy_on_write_gnu",
        "full_copy_explicit",
        "fresh",
    ])
    expected_oid_length = object_format == "sha256" ? 64 : 40
    for dependency in dependencies
        canonical_path = occursin(r"^\.\./[A-Za-z0-9._-]+$", dependency.path) &&
            dependency.path ∉ ("../.", "../..")
        add_check!(
            checks,
            "G3C_PATH_DEPENDENCY_ROW",
            canonical_path && isabspath(dependency.origin) &&
                dependency.cache_mode in allowed_cache_modes,
            dependency.path,
            "dependency path, origin, and cache mode must be canonical",
        )
        canonical_path || continue

        dependency_root = normpath(joinpath(root, dependency.path))
        repository_ok = isdir(dependency_root) && !islink(dependency_root) &&
            isdir(joinpath(dependency_root, ".git"))
        add_check!(
            checks,
            "G3C_PATH_DEPENDENCY_REPOSITORY",
            repository_ok,
            dependency.path,
            "the sibling dependency must be a real Git repository",
        )
        repository_ok || continue

        dependency_format = try
            strip(git_text(dependency_root, "rev-parse", "--show-object-format"))
        catch
            ""
        end
        oid_shape_ok = dependency_format == object_format &&
            length(dependency.head) == expected_oid_length &&
            length(dependency.index_tree) == expected_oid_length
        add_check!(
            checks,
            "G3C_PATH_DEPENDENCY_OID",
            oid_shape_ok,
            dependency.path,
            "dependency object IDs must match the repository object format",
        )
        oid_shape_ok || continue

        resolved_head = try
            strip(git_text(
                dependency_root,
                "rev-parse",
                "--verify",
                "$(dependency.head)^{commit}",
            ))
        catch
            ""
        end
        head_tree = try
            strip(git_text(dependency_root, "rev-parse", "$(dependency.head)^{tree}"))
        catch
            ""
        end
        add_check!(
            checks,
            "G3C_PATH_DEPENDENCY_OBJECT",
            resolved_head == dependency.head && head_tree == dependency.index_tree,
            dependency.path,
            "the logged dependency commit must exist and match the logged clean index tree",
        )
    end
end

function g3c_evidence_text_checks(
    log_text::AbstractString,
    commit::AbstractString;
    project_root::AbstractString=default_project_root(),
)
    root = normpath(abspath(project_root))
    checks = G3CValidationCheck[]
    normalized = replace(log_text, "\r\n" => "\n")
    lines = split(chomp(normalized), '\n'; keepempty=true)

    required_lines = [
        "G3C_PROVENANCE_VERSION=2",
        "G3C_SOURCE_CAPTURE_STABLE=true",
        "G3C_LAKE_SHARED_MUTABLE=false",
        "G3C_TEST_OUTPUT_BEGIN",
        "G3C_TEST_OUTPUT_END",
        "G3C_RESULT=PASS",
        "G3C_CLONE_DESTROYED=true",
        "G3C_METADATA_DESTROYED=true",
        "G3C_ORIGIN_HEAD_OR_INDEX_MUTATED=false",
        "G3C_PATH_DEPENDENCY_HEAD_OR_INDEX_MUTATED=false",
        "G3C_END",
    ]
    for marker in required_lines
        add_check!(
            checks,
            "G3C_REQUIRED_MARKER",
            count(==(marker), lines) == 1,
            marker,
            "required success markers must occur exactly once",
        )
    end
    add_check!(
        checks,
        "G3C_MARKER_ORDER",
        ordered_once(lines, required_lines),
        "success_markers",
        "required markers must occur in canonical execution order",
    )
    add_check!(
        checks,
        "G3C_END_LAST",
        !isempty(lines) && last(lines) == "G3C_END",
        "G3C_END",
        "the completion marker must be the final log line",
    )

    object_format = unique_value!(checks, lines, "G3C_TEST_INPUT_OBJECT_FORMAT=")
    digest = unique_value!(checks, lines, "G3C_TEST_INPUT_DIGEST=")
    ephemeral_commit = unique_value!(checks, lines, "G3C_EPHEMERAL_COMMIT=")
    ephemeral_tree = unique_value!(checks, lines, "G3C_EPHEMERAL_TREE=")
    origin_head = unique_value!(checks, lines, "G3C_ORIGIN_HEAD=")
    origin_head_after = unique_value!(checks, lines, "G3C_ORIGIN_HEAD_AFTER=")
    origin_index = unique_value!(checks, lines, "G3C_ORIGIN_INDEX_TREE=")
    origin_index_after = unique_value!(checks, lines, "G3C_ORIGIN_INDEX_TREE_AFTER=")
    result = unique_value!(checks, lines, "G3C_RESULT=")
    test_command = unique_value!(checks, lines, "G3C_TEST_COMMAND=")

    format_ok = object_format in ("sha1", "sha256")
    expected_oid_length = object_format == "sha256" ? 64 : 40
    oid_values = [digest, ephemeral_commit, ephemeral_tree, origin_head, origin_index]
    oid_shape_ok = format_ok && all(
        value -> value !== nothing && occursin(r"^[0-9a-f]+$", value) &&
            length(value) == expected_oid_length,
        oid_values,
    )
    add_check!(
        checks,
        "G3C_OID_FORMAT",
        oid_shape_ok,
        "object_ids",
        "all logged object IDs must match the declared Git object format",
    )
    add_check!(
        checks,
        "G3C_ORIGIN_STATE",
        origin_head !== nothing && origin_head == origin_head_after &&
            origin_index !== nothing && origin_index == origin_index_after,
        "origin_state",
        "origin HEAD and index tree must be unchanged",
    )
    add_check!(
        checks,
        "G3C_RESULT_VALUE",
        result == "PASS",
        "G3C_RESULT",
        "the single result field must be PASS",
    )
    add_check!(
        checks,
        "G3C_TEST_COMMAND",
        test_command == "julia --project=. -e 'using Pkg; Pkg.test()'",
        "G3C_TEST_COMMAND",
        "G3C must run one complete Pkg.test()",
    )

    if digest !== nothing && format_ok
        actual_digest, actual_format = try
            input_digest_for_commit(root, commit)
        catch
            ("", "")
        end
        add_check!(
            checks,
            "G3C_INPUT_DIGEST_MATCH",
            actual_format == object_format && actual_digest == digest,
            commit,
            "the committed test-input projection must match the logged digest",
        )
    else
        add_check!(
            checks,
            "G3C_INPUT_DIGEST_MATCH",
            false,
            commit,
            "a valid digest and object format are required",
        )
    end

    format_ok && check_path_dependencies!(checks, lines, root, commit, object_format)
    checks
end

function g3c_evidence_checks(
    log_path,
    revision;
    project_root::AbstractString=default_project_root(),
)
    root = normpath(abspath(project_root))
    checks = G3CValidationCheck[]
    path_ok = canonical_gate_log_path(log_path)
    add_check!(
        checks,
        "G3C_LOG_PATH",
        path_ok,
        string(log_path),
        "the evidence log must be a canonical repository-relative path below logs/gates",
    )
    commit = resolve_commit(root, revision)
    add_check!(
        checks,
        "G3C_COMMIT",
        commit !== nothing,
        string(revision),
        "the evidence revision must be an existing full commit object ID",
    )
    path_ok && commit !== nothing || return checks

    log_text = try
        git_text(root, "show", "$commit:$log_path")
    catch
        nothing
    end
    add_check!(
        checks,
        "G3C_COMMITTED_LOG",
        log_text !== nothing,
        log_path,
        "the evidence log must exist in the specified commit",
    )
    log_text === nothing && return checks
    append!(
        checks,
        g3c_evidence_text_checks(log_text, commit; project_root=root),
    )
    checks
end

validate_g3c_evidence(args...; kwargs...) = failures(g3c_evidence_checks(args...; kwargs...))

function committed_toml(root, commit, path)
    TOML.parse(git_text(root, "show", "$commit:$path"))
end

function g3c_transition_checks(
    evidence_revision,
    transition_revision,
    vp_id::AbstractString;
    project_root::AbstractString=default_project_root(),
)
    root = normpath(abspath(project_root))
    checks = G3CValidationCheck[]
    evidence = resolve_commit(root, evidence_revision)
    transition = resolve_commit(root, transition_revision)
    add_check!(checks, "G3C_TRANSITION_EVIDENCE_COMMIT", evidence !== nothing,
        string(evidence_revision), "evidence revision must be a full commit object ID")
    add_check!(checks, "G3C_TRANSITION_STATUS_COMMIT", transition !== nothing,
        string(transition_revision), "status revision must be a full commit object ID")
    evidence !== nothing && transition !== nothing || return checks

    parent = try
        strip(git_text(root, "rev-parse", "$transition^"))
    catch
        ""
    end
    add_check!(
        checks,
        "G3C_TRANSITION_PARENT",
        parent == evidence,
        transition,
        "the status commit must be a direct child of the verified evidence commit",
    )
    changed_paths = try
        filter(!isempty, split(chomp(git_text(
            root,
            "diff",
            "--name-only",
            evidence,
            transition,
        )), '\n'))
    catch
        String[]
    end
    add_check!(
        checks,
        "G3C_TRANSITION_CHANGED_PATHS",
        changed_paths == ["specs/ledger.toml"],
        transition,
        "only specs/ledger.toml may change in the status commit",
    )

    before = try
        committed_toml(root, evidence, "specs/ledger.toml")
    catch
        nothing
    end
    after = try
        committed_toml(root, transition, "specs/ledger.toml")
    catch
        nothing
    end
    parsed = before !== nothing && after !== nothing
    add_check!(
        checks,
        "G3C_TRANSITION_LEDGER_PARSE",
        parsed,
        vp_id,
        "both commits must contain a parseable ledger",
    )
    parsed || return checks

    before_matches = filter(vp -> get(vp, "id", nothing) == vp_id, get(before, "vp", Any[]))
    after_matches = filter(vp -> get(vp, "id", nothing) == vp_id, get(after, "vp", Any[]))
    unique_vp = length(before_matches) == 1 && length(after_matches) == 1
    add_check!(
        checks,
        "G3C_TRANSITION_VP",
        unique_vp,
        vp_id,
        "the target VP must occur exactly once in both ledgers",
    )
    unique_vp || return checks
    add_check!(
        checks,
        "G3C_TRANSITION_STATUS",
        get(only(before_matches), "status", nothing) == "bound" &&
            get(only(after_matches), "status", nothing) == "implemented",
        vp_id,
        "the only permitted transition is bound to implemented",
    )

    expected_after = deepcopy(before)
    expected_match = only(filter(
        vp -> get(vp, "id", nothing) == vp_id,
        expected_after["vp"],
    ))
    expected_match["status"] = "implemented"
    add_check!(
        checks,
        "G3C_TRANSITION_LEDGER_SEMANTICS",
        expected_after == after,
        vp_id,
        "no parsed ledger field other than the target VP status may change",
    )
    checks
end

validate_g3c_transition(args...; kwargs...) = failures(g3c_transition_checks(args...; kwargs...))

function print_result(checks)
    violations = failures(checks)
    if isempty(violations)
        println("PASS G3C evidence validation")
        return 0
    end
    println("FAIL G3C evidence validation violations=$(length(violations))")
    for violation in violations
        println("$(violation.code) subject=$(violation.subject) detail=$(violation.detail)")
    end
    1
end

function main(arguments)
    if length(arguments) == 3 && arguments[1] == "evidence"
        return print_result(g3c_evidence_checks(arguments[2], arguments[3]))
    elseif length(arguments) == 4 && arguments[1] == "transition"
        return print_result(g3c_transition_checks(arguments[2], arguments[3], arguments[4]))
    end
    println(stderr, "usage:")
    println(stderr, "  verify-g3c-evidence.sh evidence <logs/gates/...> <full-commit>")
    println(stderr, "  verify-g3c-evidence.sh transition <evidence-commit> <status-commit> <VP-id>")
    2
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end

end
