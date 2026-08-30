module CertScopeValidation

using TOML
using ERIEC

export CertScopeCheck, cert_scope_checks, validate_cert_scope

struct CertScopeCheck
    code::String
    ok::Bool
    subject::String
    detail::String
end

const _CERT_SCOPE_DETAILS = Dict(
    "CERT_SCOPE_MISSING" => "claim_scope is required",
    "CERT_SCOPE_FORBIDDEN" => "permanent, final, and unconditional cross-context scopes are forbidden",
    "CERT_SCOPE_UNKNOWN" => "claim_scope must be a registered enum value",
)

function cert_scope_checks(envelope; subject::AbstractString="envelope")
    violations = Set(ERIEC.cert_scope_violation_codes(envelope))
    [
        CertScopeCheck(code, !(code in violations), String(subject), _CERT_SCOPE_DETAILS[code])
        for code in ERIEC.CERT_SCOPE_VIOLATION_CODES
    ]
end

function cert_scope_checks(
    envelope_path::AbstractString;
    subject::AbstractString=basename(envelope_path),
)
    cert_scope_checks(TOML.parsefile(envelope_path); subject=subject)
end

function validate_cert_scope(envelope; kwargs...)
    filter(check -> !check.ok, cert_scope_checks(envelope; kwargs...))
end

end
