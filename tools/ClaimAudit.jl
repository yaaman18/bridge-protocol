isdefined(@__MODULE__, :ModelAudit) || include("ModelAudit.jl")

module ClaimAudit

import ..ModelAudit
using TOML

struct AuditClaim
    claim_id::String
    context::ModelAudit.AuditContext
    proposition::String
    verdict::Symbol
    reason::String
    evidence::Tuple{Vararg{String}}
    function AuditClaim(; claim_id, context::ModelAudit.AuditContext, proposition, verdict, reason, evidence=())
        verdict isa Symbol && verdict in (:affirmed, :denied, :undetermined) ||
            throw(ArgumentError("invalid claim verdict"))
        refs = ModelAudit._audit_strings(evidence)
        verdict == :undetermined || !isempty(refs) || throw(ArgumentError("affirmed/denied claims require evidence references"))
        new(ModelAudit._audit_text(claim_id), context, ModelAudit._audit_text(proposition), verdict,
            ModelAudit._audit_text(reason), refs)
    end
end

function claim_record(claim::AuditClaim)
    data = Dict{String,Any}("schema_version" => 1, "phenomenal_claim" => "not_certified",
        "claim_id" => claim.claim_id, "context" => ModelAudit._context_dict(claim.context),
        "proposition" => claim.proposition, "verdict" => String(claim.verdict),
        "reason" => claim.reason, "evidence" => collect(claim.evidence))
    data["digest"] = ModelAudit._audit_digest(data)
    data
end

function parse_claim_record(data::AbstractDict; expected_digest=nothing)
    ModelAudit._exact_keys(data, ("schema_version", "phenomenal_claim", "claim_id", "context",
                                 "proposition", "verdict", "reason", "evidence", "digest"))
    typeof(data["schema_version"]) == Int && data["schema_version"] == 1 &&
        data["phenomenal_claim"] == "not_certified" || throw(ArgumentError("invalid claim schema or marker"))
    data["verdict"] isa String && data["digest"] isa String || throw(ArgumentError("invalid claim strings"))
    claim = AuditClaim(claim_id=data["claim_id"], context=ModelAudit._parse_context(data["context"]),
        proposition=data["proposition"], verdict=Symbol(data["verdict"]), reason=data["reason"], evidence=data["evidence"])
    canonical = claim_record(claim)
    ModelAudit._audit_digest(data) == ModelAudit._audit_digest(canonical) || throw(ArgumentError("claim content digest mismatch"))
    expected_digest === nothing || canonical["digest"] == expected_digest || throw(ArgumentError("claim differs from external expected digest"))
    claim
end

function compare_claim_records(a::AuditClaim, b::AuditClaim)
    left, right = claim_record(a), claim_record(b)
    a.claim_id == b.claim_id && left["digest"] != right["digest"] &&
        throw(ArgumentError("claim ID reused with different content"))
    result = ModelAudit.compare_audit_claims(a, b)
    Dict("schema_version" => 1, "left" => left, "right" => right,
        "classification" => String(result.classification), "differences" => String.(collect(result.differences)),
        "opposite_verdicts" => result.opposite, "same_context" => result.same_context,
        "comparison_basis" => "exact_context_and_proposition_values",
        "evidence_verified" => false, "residual_status_updated" => false,
        "phenomenal_claim" => "not_certified", "interpretation" => "requires_review")
end

end
