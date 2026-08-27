module ClaimLedgerValidation

using SHA
using TOML

export LedgerCheck, claim_ledger_checks, validate_claim_ledger

struct LedgerCheck
    code::String
    ok::Bool
    subject::String
    detail::String
end

function add_check!(checks, code, ok, subject, detail)
    push!(checks, LedgerCheck(code, ok, subject, detail))
end

function default_project_root()
    return normpath(joinpath(@__DIR__, "..", ".."))
end

"""
Return every validation check performed for a claim ledger.

Keeping successful checks in the result lets the normal test suite preserve its
per-assertion coverage while mutation tooling consumes the failed subset through
`validate_claim_ledger`.
"""
function claim_ledger_checks(
    ledger_path::AbstractString;
    project_root::AbstractString=default_project_root(),
)
    root = normpath(abspath(project_root))
    ledger = TOML.parsefile(ledger_path)
    claims = ledger["claim"]
    groups = ledger["claim_group"]
    defaults = ledger["defaults"]
    migration = get(ledger, "migration", Dict{String,Any}())
    checks = LedgerCheck[]

    claim_ids = [claim["id"] for claim in claims]
    add_check!(
        checks,
        "CLAIM_IDS_NOT_UNIQUE",
        allunique(claim_ids),
        "ledger",
        "claim ids must be unique",
    )
    claims_by_id = Dict(claim["id"] => claim for claim in claims)
    catalog_path = joinpath(root, "formal", "ERIEC", "CertifiedArtifact.lean")
    catalog_text = read(catalog_path, String)

    for group in groups
        group_id = group["id"]
        children_known = all(child -> haskey(claims_by_id, child), group["children"])
        add_check!(
            checks,
            "GROUP_CHILD_UNKNOWN",
            children_known,
            group_id,
            "every group child must identify a claim",
        )
        if group["coverage"] == "complete"
            frozen = children_known && all(
                child -> get(claims_by_id[child], "spec_status", defaults["spec_status"]) ==
                    "frozen",
                group["children"],
            )
            add_check!(
                checks,
                "COMPLETE_GROUP_CHILD_NOT_FROZEN",
                frozen,
                group_id,
                "complete group children must have frozen statements",
            )
        end
    end

    for claim in claims
        claim_id = claim["id"]
        expected_claim_text_hash = "sha256:" * bytes2hex(sha256(codeunits(
            claim["statement_ja"] * "\n" * claim["conclusion"],
        )))
        has_claim_hash = haskey(claim, "claim_text_hash")
        add_check!(
            checks,
            "CLAIM_TEXT_HASH_MISSING",
            has_claim_hash,
            claim_id,
            "claim_text_hash is required",
        )
        if has_claim_hash
            add_check!(
                checks,
                "CLAIM_TEXT_HASH_MISMATCH",
                claim["claim_text_hash"] == expected_claim_text_hash,
                claim_id,
                "claim_text_hash must bind statement_ja and conclusion",
            )
        end

        has_falsification = haskey(claim, "falsification_ja")
        add_check!(
            checks,
            "FALSIFICATION_MISSING",
            has_falsification,
            claim_id,
            "falsification_ja is required",
        )
        if has_falsification
            add_check!(
                checks,
                "FALSIFICATION_EMPTY",
                !isempty(strip(claim["falsification_ja"])),
                claim_id,
                "falsification_ja must not be empty",
            )
        end

        add_check!(
            checks,
            "LEAN_FILE_MISSING",
            isfile(joinpath(root, claim["lean_file"])),
            claim_id,
            "lean_file must exist",
        )
        if haskey(claim, "statement_spec")
            statement_path = joinpath(root, claim["statement_spec"])
            statement_exists = isfile(statement_path)
            add_check!(
                checks,
                "STATEMENT_SPEC_MISSING",
                statement_exists,
                claim_id,
                "statement_spec must exist",
            )
            actual_hash = statement_exists ?
                "sha256:" * bytes2hex(sha256(read(statement_path))) : ""
            add_check!(
                checks,
                "STATEMENT_HASH_MISMATCH",
                statement_exists && get(claim, "statement_hash", "") == actual_hash,
                claim_id,
                "statement_hash must bind statement_spec",
            )
        end

        if get(claim, "proof_status", defaults["proof_status"]) == "unproved"
            add_check!(
                checks,
                "UNPROVED_CLAIM_NOT_CONJECTURE",
                claim["claim_kind"] == "conjecture",
                claim_id,
                "unproved claims must be conjectures",
            )
            add_check!(
                checks,
                "UNPROVED_CLAIM_NOT_OBSERVATION_ONLY",
                get(claim, "checker_relation", "") == "observation_only",
                claim_id,
                "unproved claims must use observation_only checkers",
            )
        end

        if haskey(claim, "contract_id")
            has_certified_hash = haskey(claim, "certified_text_hash")
            add_check!(
                checks,
                "CERTIFIED_TEXT_HASH_MISSING",
                has_certified_hash,
                claim_id,
                "certified claims require certified_text_hash",
            )
            if has_certified_hash && has_claim_hash
                add_check!(
                    checks,
                    "CERTIFIED_TEXT_HASH_MISMATCH",
                    claim["certified_text_hash"] == claim["claim_text_hash"],
                    claim_id,
                    "certified_text_hash must equal claim_text_hash",
                )
            end
            add_check!(
                checks,
                "CONTRACT_NOT_CERTIFIED",
                get(claim, "certification_status", defaults["certification_status"]) ==
                    "certified",
                claim_id,
                "contract claims must be certified",
            )
            add_check!(
                checks,
                "CONTRACT_NOT_IN_CATALOG",
                occursin("id := \"$(claim["contract_id"])\"", catalog_text),
                claim_id,
                "contract_id must occur in the certificate catalog",
            )
            certification_log = get(claim, "certification_log", "")
            add_check!(
                checks,
                "CERTIFICATION_LOG_MISSING",
                !isempty(certification_log) && isfile(joinpath(root, certification_log)),
                claim_id,
                "certification_log must exist",
            )
        end
    end

    falsification_pending = count(
        claim -> get(claim, "falsification_ja", "") == "未記入",
        claims,
    )
    pending_max = get(migration, "falsification_pending_max", nothing)
    add_check!(
        checks,
        "FALSIFICATION_PENDING_MAX_EXCEEDED",
        pending_max isa Integer && falsification_pending <= pending_max,
        "migration",
        "pending falsification count must not exceed falsification_pending_max",
    )
    add_check!(
        checks,
        "FALSIFICATION_PENDING_MAX_ABOVE_INITIAL",
        pending_max isa Integer && pending_max <= 91,
        "migration",
        "falsification_pending_max must not exceed the initial observed debt",
    )

    return checks
end

function validate_claim_ledger(
    ledger_path::AbstractString;
    project_root::AbstractString=default_project_root(),
)
    return filter(
        check -> !check.ok,
        claim_ledger_checks(ledger_path; project_root=project_root),
    )
end

end
