# Layer 3: criteria (RSB-GEN-001 §2, §5, §6).
#
# The engine knows only this interface. Concrete criteria that need ERIEC (DC, DC2) live in a
# plugin that depends on both ERIEC and this engine; the engine never depends on the plugin.
#
# A criterion reads a case record (the format the registered profile fixes) and a declared
# structure holding only the entries it asked for. It never receives the system, so it cannot
# read weights or thresholds through the supported API. As with the registration token, this
# is a supported-API discipline, not a security boundary against arbitrary Julia code.

"""Supertype of criteria evaluated on case records."""
abstract type AbstractCriterion end

"""Identifier; must match a name in the registered analysis plan to be run."""
function criterion_id end
"""Version string of the criterion's definition."""
function criterion_version end
"""The structure entries the criterion reads, a subset of `STRUCTURE_KEYS`."""
function required_structure end
"""
    evaluate(c, record, structure) -> Dict("values" => Dict{String,Bool}, "diagnostics" => Dict)

Decide the criterion for one case record.
"""
function evaluate end

"""Structure a criterion may declare: unit count, the role masks, and out-neighbour masks
through nonzero influences (structure of the system, not an observed relation)."""
const STRUCTURE_KEYS = (:n, :inputs, :outputs, :out_adjacency)

"""Only the entries a criterion declared. Reading an undeclared entry throws."""
struct DeclaredStructure
    entries::Dict{Symbol,Any}
end

function Base.getindex(s::DeclaredStructure, key::Symbol)
    haskey(s.entries, key) ||
        throw(ArgumentError("structure entry :$key was not declared by the criterion"))
    s.entries[key]
end
Base.keys(s::DeclaredStructure) = keys(s.entries)

"""
    declared_structure(sys, roles, wanted) -> DeclaredStructure

Build the structure a criterion declared, and nothing else.
"""
function declared_structure(sys::AbstractSystem, roles, wanted)
    entries = Dict{Symbol,Any}()
    for key in wanted
        key in STRUCTURE_KEYS || throw(ArgumentError("unknown structure entry :$key"))
        entries[key] = key === :n ? nunits(sys) :
                       key === :inputs ? roles.inputs :
                       key === :outputs ? roles.outputs :
                       out_adjacency(sys)
    end
    DeclaredStructure(entries)
end

const _CRITERION_ID = r"^[a-z0-9][a-z0-9_-]*\z"

"""Label recorded in the run-start record: id, version and the defining module, so that a
stand-in defined in a test module is visible in the record."""
criterion_label(c::AbstractCriterion) =
    "$(criterion_id(c))|$(criterion_version(c))|$(parentmodule(typeof(c)))"

function _check_identity(c::AbstractCriterion)
    id, version = criterion_id(c), criterion_version(c)
    (id isa String && occursin(_CRITERION_ID, id)) ||
        throw(ArgumentError("criterion_id must match $(_CRITERION_ID)"))
    (version isa String && !isempty(version) && !occursin('|', version)) ||
        throw(ArgumentError("criterion_version must be a nonempty string without '|'"))
    wanted = required_structure(c)
    all(k -> k in STRUCTURE_KEYS, wanted) ||
        throw(ArgumentError("required_structure must be a subset of $(STRUCTURE_KEYS)"))
    for f in fieldnames(typeof(c))
        getfield(c, f) isa AbstractSystem &&
            throw(ArgumentError("criterion $id holds a system in field :$f; criteria may not see the system"))
    end
    true
end

const CRITERION_RESULT_FIELDS = ["criterion_id", "criterion_version", "case_id", "values", "diagnostics"]

"""Evaluate one criterion on one case record and return its result record."""
function criterion_result(c::AbstractCriterion, case_id::AbstractString,
        record::AbstractDict, structure::DeclaredStructure)
    out = evaluate(c, record, structure)
    (out isa AbstractDict && sort!(collect(String, keys(out))) == ["diagnostics", "values"]) ||
        throw(ArgumentError("evaluate must return exactly \"values\" and \"diagnostics\""))
    result = Dict{String,Any}(
        "criterion_id" => criterion_id(c),
        "criterion_version" => criterion_version(c),
        "case_id" => String(case_id),
        "values" => Dict{String,Any}(String(k) => v for (k, v) in out["values"]),
        "diagnostics" => Dict{String,Any}(String(k) => v for (k, v) in out["diagnostics"]),
    )
    validate_criterion_result(result)
    result
end

"""Check a criterion result record; throws `ArgumentError`."""
function validate_criterion_result(result::AbstractDict)
    sort!(collect(String, keys(result))) == sort(CRITERION_RESULT_FIELDS) ||
        throw(ArgumentError("criterion result fields must be exactly $(CRITERION_RESULT_FIELDS)"))
    occursin(_CRITERION_ID, result["criterion_id"]) || throw(ArgumentError("criterion_id"))
    v = result["values"]
    (v isa AbstractDict && !isempty(v) && all(x -> x isa Bool, values(v))) ||
        throw(ArgumentError("values must be a nonempty table of Booleans"))
    result["diagnostics"] isa AbstractDict || throw(ArgumentError("diagnostics must be a table"))
    true
end

"""
    check_criterion_conformance(c, cases) -> true

`cases` is a collection of `(record, structure)` pairs. Checks identity, that no system is held,
that results have the required shape, and determinism (same input, same result).
"""
function check_criterion_conformance(c::AbstractCriterion, cases)
    _check_identity(c)
    for (i, (record, structure)) in enumerate(cases)
        a = criterion_result(c, "case-$i", record, structure)
        b = criterion_result(c, "case-$i", record, structure)
        a == b || throw(ArgumentError("criterion $(criterion_id(c)) is not deterministic"))
    end
    true
end

"""
    check_criteria_binding(analysis, criteria) -> true

The criteria of a run must be exactly the registered analysis plan's `recorded_criteria`, and
must include its `primary_criterion` (RSB-GEN-001 §5). Otherwise the run is refused before
anything is measured.
"""
function check_criteria_binding(analysis::AbstractDict, criteria)
    interp = analysis["interpretation"]
    recorded = collect(String, interp["recorded_criteria"])
    primary = String(interp["primary_criterion"])
    foreach(_check_identity, criteria)
    ids = [criterion_id(c) for c in criteria]
    allunique(ids) || throw(ArgumentError("duplicate criterion ids $(ids)"))
    (length(ids) == length(recorded) && Set(ids) == Set(recorded)) ||
        throw(ArgumentError("criteria $(ids) do not match the registered recorded_criteria $(recorded)"))
    primary in ids || throw(ArgumentError("primary criterion $primary is missing"))
    true
end

"""
    check_criteria_implementation(analysis, criteria, runner_repo) -> Dict(id => binding)

RSB-PLAN-002 §3.3 (RSB-BIND-001): under an analysis plan with `[[criterion_binding]]`, each
criterion must come from the registered package as checked out in the runner:
1. the tree of `package_path` at the runner's HEAD has the registered OID;
2. the criterion type is defined in a package named `package_name`;
3. that package was loaded from `package_path` inside the runner checkout (`pkgdir`);
4. `criterion_version` equals the registered value.
A test stand-in defined in a test module fails (2); a same-named package loaded from elsewhere
fails (3). Redefining `evaluate` from another module at run time is not prevented (§3.4).
"""
function check_criteria_implementation(analysis::AbstractDict, criteria, runner_repo::AbstractString)
    bindings = Dict(b["criterion_id"] => b for b in analysis["criterion_binding"])
    for c in criteria
        id = criterion_id(c)
        b = get(bindings, id, nothing)
        b === nothing && throw(ArgumentError("criterion $id has no criterion_binding"))
        path = b["package_path"]
        tree_oid_at(runner_repo, "HEAD", path) == b["package_tree_oid"] ||
            throw(ArgumentError("criterion $id: the runner's tree at $path differs from the registered OID"))
        root = Base.moduleroot(parentmodule(typeof(c)))
        String(nameof(root)) == b["package_name"] ||
            throw(ArgumentError("criterion $id is defined in $(nameof(root)), not in the registered package $(b["package_name"])"))
        dir = pkgdir(root)
        expected = joinpath(runner_repo, path)
        (dir !== nothing && isdir(expected) && realpath(dir) == realpath(expected)) ||
            throw(ArgumentError("criterion $id: package $(nameof(root)) was not loaded from $path in the runner checkout"))
        criterion_version(c) == b["criterion_version"] ||
            throw(ArgumentError("criterion $id: version $(criterion_version(c)) differs from the registered $(b["criterion_version"])"))
    end
    bindings
end

"""The result's value and diagnostic keys must equal the registered ones exactly (RSB-PLAN-002 §4.2)."""
function check_result_keys(result::AbstractDict, binding::AbstractDict)
    id = result["criterion_id"]
    sort!(collect(String, keys(result["values"]))) == sort(binding["value_keys"]) ||
        throw(ArgumentError("criterion $id: value keys differ from the registered value_keys"))
    sort!(collect(String, keys(result["diagnostics"]))) == sort(binding["diagnostic_keys"]) ||
        throw(ArgumentError("criterion $id: diagnostic keys differ from the registered diagnostic_keys"))
    true
end
