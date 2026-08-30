module CertScopeValidation

using TOML
using ERIEC

export CertScopeCheck,
    cert_scope_checks,
    validate_cert_scope,
    contract_scope_checks,
    validate_contract_scope,
    cert_scope_registry_checks,
    validate_cert_scope_registry,
    cert_scope_binding_checks,
    validate_cert_scope_binding

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
    "SCOPE_KIND_MISSING" => "scope_kind is required for every registered contract",
    "SCOPE_REGISTRY_ID_MISMATCH" => "registry contract IDs must exactly match the semantic manifest",
    "SCOPE_KIND_FORBIDDEN" => "permanent, final, and unconditional cross-context contract scopes are forbidden",
    "SCOPE_KIND_UNKNOWN" => "scope_kind must be a registered enum value",
    "PRESERVATION_DECL_MISSING" => "cross-context conditional scope requires preservation_decl",
    "PRESERVATION_DECL_NOT_IN_CATALOG" => "preservation_decl must resolve in the real certificate catalog",
    "CLAIM_SCOPE_EXCEEDS_CONTRACT" => "claim_scope exceeds at least one payload contract scope",
    "CONTRACT_SCOPE_DISPUTED" => "disputed contracts cannot support a certified envelope",
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

function _checks(codes, violations, subject)
    rejected = Set(violations)
    [
        CertScopeCheck(code, !(code in rejected), String(subject), _CERT_SCOPE_DETAILS[code])
        for code in codes
    ]
end

function contract_scope_checks(
    contract;
    subject::AbstractString="contract",
    kwargs...,
)
    violations = ERIEC.contract_scope_violation_codes(contract; kwargs...)
    _checks(ERIEC.CERT_SCOPE_BINDING_VIOLATION_CODES, violations, subject)
end

function contract_scope_checks(
    contract_path::AbstractString;
    subject::AbstractString=basename(contract_path),
    kwargs...,
)
    contract_scope_checks(TOML.parsefile(contract_path); subject=subject, kwargs...)
end

validate_contract_scope(contract; kwargs...) =
    filter(check -> !check.ok, contract_scope_checks(contract; kwargs...))

function cert_scope_registry_checks(
    registry,
    manifest;
    subject::AbstractString="registry",
    kwargs...,
)
    violations = ERIEC.cert_scope_registry_violation_codes(
        registry,
        manifest;
        kwargs...,
    )
    _checks(ERIEC.CERT_SCOPE_BINDING_VIOLATION_CODES, violations, subject)
end

validate_cert_scope_registry(registry, manifest; kwargs...) = filter(
    check -> !check.ok,
    cert_scope_registry_checks(registry, manifest; kwargs...),
)

function cert_scope_binding_checks(
    envelope,
    registry,
    manifest;
    subject::AbstractString="envelope",
    kwargs...,
)
    violations = ERIEC.cert_scope_binding_violation_codes(
        envelope,
        registry,
        manifest;
        kwargs...,
    )
    _checks(ERIEC.CERT_SCOPE_BINDING_VIOLATION_CODES, violations, subject)
end

validate_cert_scope_binding(envelope, registry, manifest; kwargs...) = filter(
    check -> !check.ok,
    cert_scope_binding_checks(envelope, registry, manifest; kwargs...),
)

end
