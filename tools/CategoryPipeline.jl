module CategoryPipeline

using SHA
using TOML

export Impact,
    GateResult,
    category_sections,
    compute_impact,
    load_ledger,
    load_manifest,
    validate_configuration,
    write_baseline,
    write_report,
    run_gates

struct Impact
    changed_sections::Vector{String}
    removed_sections::Vector{String}
    direct_vps::Vector{String}
    impacted_vps::Vector{String}
    unmapped_sections::Vector{String}
end

struct GateResult
    name::String
    command::Vector{String}
    passed::Bool
    log::String
end

function category_sections(path::AbstractString)
    isfile(path) || throw(ArgumentError("category document not found: $path"))
    sections = Dict{String,NamedTuple{(:heading, :sha256),Tuple{String,String}}}()
    current_id = nothing
    current_heading = ""
    buffer = String[]

    function finish_section!()
        current_id === nothing && return
        body = join(buffer, "\n") * "\n"
        sections[current_id] = (heading=current_heading, sha256=bytes2hex(sha256(body)))
    end

    for line in eachline(path)
        match_result = match(r"^##\s+(§[0-9]+)\.\s*(.*)$", line)
        if match_result !== nothing
            finish_section!()
            current_id = match_result.captures[1]
            current_heading = strip(match_result.captures[2])
            empty!(buffer)
        end
        current_id === nothing || push!(buffer, line)
    end
    finish_section!()
    isempty(sections) && throw(ArgumentError("no '## §N.' sections found in $path"))
    sections
end

function load_manifest(path::AbstractString)
    data = TOML.parsefile(path)
    get(data, "schema_version", 0) == 1 ||
        throw(ArgumentError("unsupported impact manifest schema"))
    haskey(data, "document") || throw(ArgumentError("impact manifest has no document"))
    data
end

function load_ledger(path::AbstractString)
    data = TOML.parsefile(path)
    get(data, "schema_version", 0) == 1 ||
        throw(ArgumentError("unsupported ledger schema"))
    entries = get(data, "vp", Any[])
    Dict(String(entry["id"]) => entry for entry in entries)
end

function _manifest_sections(manifest)
    Dict(String(entry["id"]) => entry for entry in get(manifest, "section", Any[]))
end

function _baseline_sections(path::AbstractString)
    isfile(path) || return Dict{String,String}()
    data = TOML.parsefile(path)
    get(data, "schema_version", 0) == 1 ||
        throw(ArgumentError("unsupported category baseline schema"))
    Dict(String(entry["id"]) => String(entry["sha256"]) for entry in get(data, "section", Any[]))
end

function _assert_dag(ledger)
    state = Dict(id => 0 for id in keys(ledger))
    function visit(id)
        state[id] == 2 && return
        state[id] == 1 && throw(ArgumentError("ledger dependency cycle at $id"))
        state[id] = 1
        for dependency in get(ledger[id], "depends_on", Any[])
            dependency = String(dependency)
            haskey(ledger, dependency) ||
                throw(ArgumentError("$id depends on unknown VP $dependency"))
            visit(dependency)
        end
        state[id] = 2
    end
    foreach(visit, keys(ledger))
    nothing
end

function validate_configuration(root::AbstractString, manifest, ledger)
    document = joinpath(root, String(manifest["document"]))
    current = category_sections(document)
    mapped = _manifest_sections(manifest)
    errors = String[]

    for id in setdiff(keys(current), keys(mapped))
        push!(errors, "document section $id is absent from impact manifest")
    end
    for id in setdiff(keys(mapped), keys(current))
        push!(errors, "impact manifest section $id is absent from document")
    end
    for (section_id, entry) in mapped
        vp_ids = get(entry, "vp_ids", Any[])
        all_vps = get(entry, "all_vps", false)
        if isempty(vp_ids) && !all_vps
            push!(errors, "$section_id has no VP mapping; use all_vps=true for a global section")
        end
        !isempty(vp_ids) && all_vps &&
            push!(errors, "$section_id cannot set both vp_ids and all_vps=true")
        for vp_id in get(entry, "vp_ids", Any[])
            haskey(ledger, String(vp_id)) ||
                push!(errors, "$section_id references unknown VP $vp_id")
        end
        for test_file in get(entry, "tests", Any[])
            isfile(joinpath(root, String(test_file))) ||
                push!(errors, "$section_id references missing test $test_file")
        end
    end
    try
        _assert_dag(ledger)
    catch error
        push!(errors, sprint(showerror, error))
    end
    errors
end

function compute_impact(root::AbstractString, manifest, ledger, baseline_path::AbstractString)
    current = category_sections(joinpath(root, String(manifest["document"])))
    baseline = _baseline_sections(baseline_path)
    mapping = _manifest_sections(manifest)
    changed = sort!([
        id for (id, snapshot) in current
        if get(baseline, id, "") != snapshot.sha256
    ])
    removed = sort!(collect(setdiff(keys(baseline), keys(current))))
    direct = Set{String}()
    unmapped = String[]
    for section_id in changed
        entry = get(mapping, section_id, Dict())
        vp_ids = get(entry, "all_vps", false) ? collect(keys(ledger)) :
            String.(get(entry, "vp_ids", Any[]))
        if isempty(vp_ids)
            push!(unmapped, section_id)
        else
            union!(direct, vp_ids)
        end
    end

    impacted = copy(direct)
    changed_set = true
    while changed_set
        changed_set = false
        for (id, entry) in ledger
            id in impacted && continue
            if any(String(dep) in impacted for dep in get(entry, "depends_on", Any[]))
                push!(impacted, id)
                changed_set = true
            end
        end
    end
    Impact(changed, removed, sort!(collect(direct)), sort!(collect(impacted)), sort!(unmapped))
end

function _lean_targets_for_impact(ledger, impact::Impact)
    targets = Set{String}()
    for id in impact.impacted_vps
        lean_file = String(ledger[id]["lean_file"])
        lean_file == "-" && continue
        matched = match(r"^formal/(.+)\.lean$", lean_file)
        matched === nothing &&
            throw(ArgumentError("$id has unsupported Lean file path: $lean_file"))
        push!(targets, replace(matched.captures[1], '/' => '.'))
    end
    sort!(collect(targets))
end

function write_baseline(
    path::AbstractString,
    document::AbstractString;
    document_label::AbstractString=document,
)
    snapshots = category_sections(document)
    data = Dict{String,Any}(
        "schema_version" => 1,
        "document" => document_label,
        "section" => [
            Dict("id" => id, "sha256" => snapshots[id].sha256)
            for id in sort!(collect(keys(snapshots)))
        ],
    )
    mkpath(dirname(path))
    temporary = path * ".tmp"
    open(temporary, "w") do io
        TOML.print(io, data; sorted=true)
    end
    mv(temporary, path; force=true)
    path
end

function _command_log(root, name)
    log_dir = joinpath(root, "logs", "category-pipeline")
    mkpath(log_dir)
    joinpath(log_dir, name * ".log")
end

function _run_gate(root, name, command)
    log = _command_log(root, name)
    passed = open(log, "w") do io
        process = run(pipeline(ignorestatus(Cmd(Cmd(command); dir=root)), stdout=io, stderr=io))
        success(process)
    end
    GateResult(name, command, passed, relpath(log, root))
end

function _binding_gate(root, ledger, impact::Impact)
    name = "G1-impacted-bindings"
    log = _command_log(root, name)
    problems = String[]
    for id in impact.impacted_vps
        entry = ledger[id]
        status = String(entry["status"])
        lean_file = joinpath(root, String(entry["lean_file"]))
        julia_file = joinpath(root, String(entry["julia_file"]))
        if status in ("formalized", "bound", "implemented", "certified")
            if !isfile(lean_file)
                push!(problems, "$id: missing Lean file $(entry["lean_file"])")
            else
                declaration = last(split(String(entry["lean_decl"]), '.'))
                occursin(Regex("\\b" * declaration * "\\b"), read(lean_file, String)) ||
                    push!(problems, "$id: missing Lean declaration $(entry["lean_decl"])")
            end
        end
        if status in ("bound", "implemented", "certified")
            if !isfile(julia_file)
                push!(problems, "$id: missing Julia file $(entry["julia_file"])")
            else
                api = String(entry["julia_api"])
                occursin(Regex("\\b" * api * "\\b"), read(julia_file, String)) ||
                    push!(problems, "$id: missing Julia API $api")
            end
        end
    end
    open(log, "w") do io
        if isempty(problems)
            println(io, "all impacted ledger bindings exist")
        else
            foreach(problem -> println(io, problem), problems)
        end
    end
    GateResult(name, ["internal:validate-impacted-bindings"], isempty(problems), relpath(log, root))
end

function _tests_for_impact(manifest, impact::Impact)
    mapping = _manifest_sections(manifest)
    tests = Set{String}()
    impacted = Set(impact.impacted_vps)
    for entry in values(mapping)
        if any(String(vp_id) in impacted for vp_id in get(entry, "vp_ids", Any[]))
            for test_file in get(entry, "tests", Any[])
                push!(tests, String(test_file))
            end
        end
    end
    sort!(collect(tests))
end

function run_gates(root::AbstractString, manifest, ledger, impact::Impact)
    isempty(impact.unmapped_sections) || return GateResult[]
    isempty(impact.removed_sections) || return GateResult[]
    isempty(impact.changed_sections) && return GateResult[]

    results = GateResult[]
    push!(results, _binding_gate(root, ledger, impact))
    results[end].passed || return results
    lean_targets = _lean_targets_for_impact(ledger, impact)
    if !isempty(lean_targets)
        push!(results, _run_gate(root, "G1-lean-build", ["lake", "build", lean_targets...]))
        results[end].passed || return results
    end
    push!(results, _run_gate(
        root,
        "G2-formal-julia-contract",
        ["julia", "--project=.", "-e", "using Test; using ERIEC; include(\"test/test_formal_julia_contract.jl\")"],
    ))
    results[end].passed || return results

    tests = _tests_for_impact(manifest, impact)
    if !isempty(tests)
        expression = "using Test; using ERIEC; " *
            join(["include(\"$(replace(path, "\"" => "\\\""))\")" for path in tests], "; ")
        push!(results, _run_gate(root, "G3-impacted-julia-tests", ["julia", "--project=.", "-e", expression]))
        results[end].passed || return results
    end

    push!(results, _run_gate(
        root,
        "G4-certified-artifact",
        ["julia", "--project=.", "-e", "using ERIEC; c=verify_lean_certified_artifact(); @assert certified_artifact_ok(c)"],
    ))
    results
end

function write_report(path::AbstractString, impact::Impact, ledger, gates::Vector{GateResult})
    lines = String[
        "# 圏論更新・影響レポート",
        "",
        "- 変更節: " * (isempty(impact.changed_sections) ? "なし" : join(impact.changed_sections, ", ")),
        "- 削除節: " * (isempty(impact.removed_sections) ? "なし" : join(impact.removed_sections, ", ")),
        "- 直接影響VP: " * (isempty(impact.direct_vps) ? "なし" : join(impact.direct_vps, ", ")),
        "- 依存閉包VP: " * (isempty(impact.impacted_vps) ? "なし" : join(impact.impacted_vps, ", ")),
        "- 台帳起票が必要な節: " * (isempty(impact.unmapped_sections) ? "なし" : join(impact.unmapped_sections, ", ")),
        "",
        "## 更新対象",
        "",
    ]
    if isempty(impact.impacted_vps)
        push!(lines, "更新対象なし。")
    else
        push!(lines, "| VP | Lean | Julia | status |")
        push!(lines, "|---|---|---|---|")
        for id in impact.impacted_vps
            entry = ledger[id]
            push!(lines, "| $id | `$(entry["lean_file"])` / `$(entry["lean_decl"])` | `$(entry["julia_file"])` / `$(entry["julia_api"])` | `$(entry["status"])` |")
        end
    end
    push!(lines, "", "## ゲート", "")
    if isempty(gates)
        push!(lines, "未実行。")
    else
        push!(lines, "| gate | result | log |")
        push!(lines, "|---|---|---|")
        for gate in gates
            push!(lines, "| $(gate.name) | $(gate.passed ? "pass" : "fail") | `$(gate.log)` |")
        end
    end
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, join(lines, "\n") * "\n")
    end
    path
end

end
