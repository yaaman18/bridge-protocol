"""
Measurement engine for finite deterministic systems under source silencing
(RSB-002, generalised by RSB-GEN-001).

Three layers, depending one way (3 → 2 → 1):

1. system (`AbstractSystem`, `step`): the reactivation substrate and an elementary cellular
   automaton implement it;
2. response (`measure_response`, `ResponseTable`): the response to silencing each measured
   set of units, with no notion of roles, relations or criteria;
3. reading and judging: record formats (`read_record`) and criteria (`AbstractCriterion`).

It does not evaluate DC, build an `ERIEState`, or compute a boundary. Criteria that need ERIEC
belong in a plugin that depends on this engine; this engine must not depend on ERIEC.
The only intervention is source silencing (see system.jl).
"""
module ReactivationMeasurement

using SHA
using TOML
using SubstrateRegistry

export AbstractSystem, nunits, check_system_conformance, MAX_UNITS,
    Substrate, Protocol, substrate_from_profile, roles, out_adjacency, ElementaryCA,
    ResponseTable, measure_response, silencing_sets, is_exhaustive, losses,
    minimal_loss_sets, collective_only_loss,
    AbstractRecordFormat, RSBCaseRecordV1, ResponseRecordV1, format_id, read_record,
    measure_case, validate_response_record, RESPONSE_RECORD_FORMAT,
    CASE_RECORD_FORMAT, CASE_RECORD_FIELDS, validate_case_record,
    AbstractCriterion, criterion_id, criterion_version, required_structure, evaluate,
    DeclaredStructure, declared_structure, STRUCTURE_KEYS, criterion_label,
    criterion_result, validate_criterion_result, check_criterion_conformance,
    check_criteria_binding, check_criteria_implementation, check_result_keys,
    seal_entries, retry_mismatches,
    start_run

include("system.jl")
include("substrate.jl")
include("cellular.jl")
include("response.jl")
include("records.jl")
include("formats.jl")
include("criteria.jl")
include("run.jl")

end
