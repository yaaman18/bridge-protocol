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
