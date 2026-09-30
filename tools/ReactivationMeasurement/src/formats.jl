# Record formats: how a response table is written down (RSB-GEN-001 §2, §4, §8).
#
# A format is selected by the registered profile's [output] section, so the format itself is
# preregistered. Two formats exist:
#
# - rsb-case-record-v1: the format the registered reactivation profiles freeze. It reads the
#   response through a role assignment (inputs E, outputs M) into the observed relations
#   pi/rho/alpha/sigma. It needs every silencing set and must stay byte-identical to the RSB-002
#   engine (checked against test/legacy_engine.jl).
# - rsb-response-record-v1: a role-free record of the raw response, usable for any system and
#   any `max_silencing_order`. Its loss fields are named "..._up_to_order" so that an
#   order-limited record cannot be read as a statement about every silencing set.

"""Supertype of record formats."""
abstract type AbstractRecordFormat end

"""The format identifier written in profiles and records."""
function format_id end

"""
    read_record(fmt, table, roles) -> Dict{String,Any}

Write the response table in format `fmt`. `roles` is a named tuple `(inputs, outputs)` of bit
masks; formats that do not read roles ignore it.
"""
function read_record end

struct RSBCaseRecordV1 <: AbstractRecordFormat end
format_id(::RSBCaseRecordV1) = CASE_RECORD_FORMAT

function read_record(::RSBCaseRecordV1, t::ResponseTable, roles)
    is_exhaustive(t) ||
        throw(ArgumentError("$CASE_RECORD_FORMAT needs every silencing set; " *
            "this table was measured up to order $(t.max_silencing_order) of $(t.n)"))
    n = t.n
    loss = losses(t)
    baseline_final = t.final[1]
    single(u) = (1 << u) + 1
    pi = [loss[single(u)] for u in 0:(n - 1)]
    rho = [loss[single(u)] & roles.outputs for u in 0:(n - 1)]
    alpha = [(baseline_final ⊻ t.final[single(u)]) & roles.inputs for u in 0:(n - 1)]
    sigma = [(baseline_final ⊻ t.final[single(u)]) & roles.outputs for u in 0:(n - 1)]
    loss_sets = [_minimal_loss_sets(loss, c) for c in 0:(n - 1)]
    collective = 0
    for c in 0:(n - 1)
        sets = loss_sets[c + 1]
        (!isempty(sets) && all(a -> count_ones(a) >= 2, sets)) && (collective |= 1 << c)
    end
    Dict{String,Any}(
        "q" => t.q,
        "preparation_trace" => copy(t.preparation_trace),
        "z" => t.z,
        "kappa" => t.prefix_persistent,
        "epsilon" => t.z & roles.inputs,
        "future_final" => copy(t.final),
        "future_persistent" => copy(t.persistent),
        "pi" => pi,
        "rho" => rho,
        "alpha" => alpha,
        "sigma" => sigma,
        "loss_sets" => loss_sets,
        "collective_only_loss" => collective,
    )
end

"""
    measure_case(sub, proto, q) -> Dict

All observations for initial configuration `q` in `rsb-case-record-v1` (RSB-002). Relations
are recorded for every unit; restricting them to M = O and E = I is left to the reader.
"""
measure_case(sub::Substrate, proto::Protocol, q::Integer) =
    read_record(RSBCaseRecordV1(), measure_response(sub, proto, q), roles(sub))

const RESPONSE_RECORD_FORMAT = "rsb-response-record-v1"
const RESPONSE_RECORD_FIELDS = ["record_format", "n", "q", "preparation_trace", "z",
    "prefix_persistent", "max_silencing_order", "silencing_sets", "final", "persistent",
    "loss_sets_up_to_order", "collective_only_loss_up_to_order"]

struct ResponseRecordV1 <: AbstractRecordFormat end
format_id(::ResponseRecordV1) = RESPONSE_RECORD_FORMAT

function read_record(::ResponseRecordV1, t::ResponseTable, _roles=nothing)
    Dict{String,Any}(
        "record_format" => RESPONSE_RECORD_FORMAT,
        "n" => t.n,
        "q" => t.q,
        "preparation_trace" => copy(t.preparation_trace),
        "z" => t.z,
        "prefix_persistent" => t.prefix_persistent,
        "max_silencing_order" => t.max_silencing_order,
        "silencing_sets" => copy(t.silencing_sets),
        "final" => copy(t.final),
        "persistent" => copy(t.persistent),
        "loss_sets_up_to_order" => [minimal_loss_sets(t, c) for c in 0:(t.n - 1)],
        "collective_only_loss_up_to_order" => collective_only_loss(t),
    )
end

"""Check a `rsb-response-record-v1` record; throws `ArgumentError` listing problems."""
function validate_response_record(record::AbstractDict)
    errors = String[]
    sort!(collect(String, keys(record))) == sort(RESPONSE_RECORD_FIELDS) ||
        throw(ArgumentError("fields must be exactly $(RESPONSE_RECORD_FIELDS)"))
    record["record_format"] == RESPONSE_RECORD_FORMAT || push!(errors, "record_format")
    n = record["n"]
    (n isa Int64 && 1 <= n <= MAX_UNITS) || throw(ArgumentError("invalid record: n"))
    k = record["max_silencing_order"]
    (k isa Int64 && 1 <= k <= n) || push!(errors, "max_silencing_order")
    if isempty(errors)
        record["silencing_sets"] == silencing_sets(n, k) || push!(errors, "silencing_sets")
        m = length(record["silencing_sets"])
        for key in ("final", "persistent")
            _is_mask_list(record[key], n, m) || push!(errors, key)
        end
        pt = record["preparation_trace"]
        (pt isa AbstractVector && !isempty(pt) && all(v -> _is_mask(v, n), pt)) ||
            push!(errors, "preparation_trace")
        for key in ("q", "z", "prefix_persistent", "collective_only_loss_up_to_order")
            _is_mask(record[key], n) || push!(errors, key)
        end
        ls = record["loss_sets_up_to_order"]
        (ls isa AbstractVector && length(ls) == n &&
            all(v -> v isa AbstractVector && all(a -> _is_mask(a, n) && count_ones(a) <= k, v), ls)) ||
            push!(errors, "loss_sets_up_to_order")
    end
    isempty(errors) || throw(ArgumentError("invalid response record: " * join(errors, ", ")))
    true
end
