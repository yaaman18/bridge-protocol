# Case record (the output schema fixed by the profile's [output] section, RSB-002 §5).
# The field list is exact: there is no field for DC conditions, Act, the boundary or
# nonemptiness flags, so such values cannot be written by the measurement engine.

const CASE_RECORD_FORMAT = "rsb-case-record-v1"
const SET_ENCODING = "unit_index_lsb_bitmask"
const CASE_RECORD_FIELDS = ["case_id", "q", "preparation_trace", "z", "kappa", "epsilon",
    "future_final", "future_persistent", "pi", "rho", "alpha", "sigma", "loss_sets",
    "collective_only_loss"]

_is_mask(x, n) = x isa Int64 && 0 <= x < (1 << n)
_is_mask_list(x, n, len) = x isa AbstractVector && length(x) == len && all(v -> _is_mask(v, n), x)

"""Check a case record against the output schema; throws `ArgumentError` listing problems."""
function validate_case_record(record::AbstractDict, sub::Substrate, proto::Protocol)
    errors = String[]
    keys_found = sort!(collect(String, keys(record)))
    keys_found == sort(CASE_RECORD_FIELDS) ||
        push!(errors, "fields must be exactly $(CASE_RECORD_FIELDS); got $(keys_found)")
    if isempty(errors)
        n = sub.n
        nsets = 1 << n
        occursin(r"^case-[0-9]+\z", record["case_id"]) || push!(errors, "case_id")
        _is_mask(record["q"], n) || push!(errors, "q")
        _is_mask_list(record["preparation_trace"], n, proto.preparation_steps + 1) ||
            push!(errors, "preparation_trace")
        for key in ("z", "kappa", "epsilon", "collective_only_loss")
            _is_mask(record[key], n) || push!(errors, key)
        end
        for key in ("future_final", "future_persistent")
            _is_mask_list(record[key], n, nsets) || push!(errors, key)
        end
        for key in ("pi", "rho", "alpha", "sigma")
            _is_mask_list(record[key], n, n) || push!(errors, key)
        end
        ls = record["loss_sets"]
        (ls isa AbstractVector && length(ls) == n &&
            all(v -> v isa AbstractVector && all(a -> _is_mask(a, n), v), ls)) ||
            push!(errors, "loss_sets")
    end
    isempty(errors) || throw(ArgumentError("invalid case record: " * join(errors, ", ")))
    true
end

"""Refuse to run unless the profile fixes exactly this engine's output schema."""
function _check_output_schema(profile::AbstractDict)
    o = profile["output"]
    (get(o, "case_record_format", nothing) == CASE_RECORD_FORMAT &&
        get(o, "set_encoding", nothing) == SET_ENCODING &&
        get(o, "case_record_fields", nothing) == CASE_RECORD_FIELDS) ||
        throw(ArgumentError("the profile does not fix this engine's output schema ($CASE_RECORD_FORMAT)"))
    true
end
