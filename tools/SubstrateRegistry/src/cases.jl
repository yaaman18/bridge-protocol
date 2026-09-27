# Ordered case digest (RSB-001 §7b).
#
# IDs: ASCII `[a-z0-9][a-z0-9._-]{0,63}` (a subset of UTF-8, so no normalization step).
# Encoding: length-prefixed, independent of any delimiter, no trailing newline:
#   u32be(len(version)) version  u64be(count)  { u32be(len(id)) id }*
# Order: the profile's `case_order`; only `ascending_integer` is defined.
# Algorithm: SHA-256, reported as lowercase hex.

const CASE_DIGEST_VERSION = "rsb-case-digest-v1"

function _check_case_id(id::AbstractString)
    (isascii(id) && occursin(ID_PATTERN, id)) ||
        throw(ArgumentError("invalid case id $(repr(id))"))
    id
end

"""Case IDs in the order fixed by the profile."""
function canonical_case_ids(profile::AbstractDict)
    e = profile["enumeration"]
    e["case_order"] == "ascending_integer" ||
        throw(ArgumentError("unsupported case_order $(repr(e["case_order"]))"))
    n = e["case_count"]
    width = ndigits(max(n - 1, 0))
    ["case-" * lpad(string(i), width, '0') for i in 0:(n - 1)]
end

function case_digest(ids::AbstractVector{<:AbstractString})
    io = IOBuffer()
    put(s) = (b = codeunits(s); write(io, hton(UInt32(length(b)))); write(io, b))
    put(CASE_DIGEST_VERSION)
    write(io, hton(UInt64(length(ids))))
    for id in ids
        put(_check_case_id(id))
    end
    bytes2hex(sha256(take!(io)))
end
