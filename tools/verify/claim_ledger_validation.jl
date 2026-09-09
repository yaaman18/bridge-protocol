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

function legacy_coverage_checks(ledger_path::AbstractString, root::AbstractString)
    checks = LedgerCheck[]
    exists = isfile(ledger_path)
    add_check!(checks, "LEGACY_LEDGER_MISSING", exists, "legacy ledger",
        "the v1 ledger must exist so coverage audits cannot be skipped")
    exists || return checks

    ledger = TOML.parsefile(ledger_path)
    vps = get(ledger, "vp", Any[])
    rows = get(ledger, "legacy_coverage", Any[])
    valid_vps = vps isa AbstractVector && !isempty(vps) &&
        all(vp -> vp isa AbstractDict && get(vp, "id", nothing) isa AbstractString, vps)
    valid_rows = rows isa AbstractVector && all(row -> row isa AbstractDict, rows)
    add_check!(checks, "LEGACY_VPS_INVALID", valid_vps, "legacy ledger",
        "vp must be a nonempty array of tables with string ids")
    add_check!(checks, "LEGACY_COVERAGE_ROWS_INVALID", valid_rows, "legacy ledger",
        "legacy_coverage must be an array of tables")
    valid_vps && valid_rows || return checks

    vp_ids = [vp["id"] for vp in vps]
    row_ids = [get(row, "legacy_vp_id", nothing) for row in rows]
    add_check!(checks, "LEGACY_VP_IDS_NOT_UNIQUE", allunique(vp_ids), "legacy ledger",
        "vp ids must be unique")
    add_check!(checks, "LEGACY_COVERAGE_IDS_NOT_UNIQUE", allunique(row_ids), "legacy ledger",
        "each VP may have at most one coverage audit row")
    vps_by_id = Dict(vp["id"] => vp for vp in vps)

    for vp in vps
        audit = get(vp, "coverage_audit", nothing)
        if get(vp, "status", nothing) == "certified" || haskey(vp, "coverage_audit")
            add_check!(checks, "LEGACY_COVERAGE_AUDIT_INVALID",
                audit in ("unreviewed", "complete"), vp["id"],
                "coverage_audit must be unreviewed or complete")
        end
        audit == "complete" || continue
        matches = filter(row -> get(row, "legacy_vp_id", nothing) == vp["id"], rows)
        complete = length(matches) == 1 && get(only(matches), "audit_status", nothing) == "complete"
        add_check!(checks, "LEGACY_COMPLETE_COVERAGE_MISSING", complete, vp["id"],
            "a complete VP requires exactly one matching complete legacy_coverage row")
    end

    for row in rows
        vp_id = get(row, "legacy_vp_id", nothing)
        subject = string(vp_id)
        known_vp = haskey(vps_by_id, vp_id)
        add_check!(checks, "LEGACY_COVERAGE_VP_UNKNOWN", known_vp, subject,
            "legacy_vp_id must identify a v1 VP")
        audit = get(row, "audit_status", nothing)
        add_check!(checks, "LEGACY_COVERAGE_STATUS_INVALID",
            audit in ("unreviewed", "complete"), subject,
            "audit_status must be unreviewed or complete")
        if known_vp
            vp = vps_by_id[vp_id]
            contract_id = get(row, "contract_id", nothing)
            add_check!(checks, "LEGACY_COVERAGE_CONTRACT_MISMATCH",
                contract_id isa AbstractString && contract_id == get(vp, "contract_id", nothing),
                subject, "the audit contract_id must match the referenced VP")
            add_check!(checks, "LEGACY_COMPLETE_VP_MISMATCH",
                audit != "complete" || get(vp, "coverage_audit", nothing) == "complete",
                subject, "a complete audit row requires the VP's coverage_audit to be complete")
        end
        basis = get(row, "basis", nothing)
        add_check!(checks, "LEGACY_COVERAGE_BASIS_INVALID",
            basis in ("exact_ledger_decl", "type_review"), subject,
            "basis must be exact_ledger_decl or type_review")
        reviewer = get(row, "reviewer", nothing)
        basis_log = get(row, "basis_log", nothing)
        evidence_exists = basis_log isa AbstractString && !isempty(strip(basis_log)) &&
            !isabspath(basis_log) && isfile(normpath(joinpath(root, basis_log)))
        add_check!(checks, "LEGACY_COVERAGE_REVIEWER_MISSING",
            reviewer isa AbstractString && !isempty(strip(reviewer)), subject,
            "every coverage audit requires a named reviewer regardless of basis")
        add_check!(checks, "LEGACY_COVERAGE_EVIDENCE_MISSING", evidence_exists, subject,
            "every coverage audit requires an existing repository-relative basis_log regardless of basis")
    end
    return checks
end

"""
Return every validation check performed for a claim ledger.

Keeping successful checks in the result lets the normal test suite preserve its
per-assertion coverage while mutation tooling consumes the failed subset through
`validate_claim_ledger`. The v1 ledger's coverage audit bindings are also checked;
`legacy_ledger_path` permits isolated fixtures without changing the live ledger.
"""
function claim_ledger_checks(
    ledger_path::AbstractString;
    project_root::AbstractString=default_project_root(),
    legacy_ledger_path::AbstractString=joinpath(project_root, "specs", "ledger.toml"),
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

    append!(checks, legacy_coverage_checks(legacy_ledger_path, root))
    return checks
end

function validate_claim_ledger(
    ledger_path::AbstractString;
    project_root::AbstractString=default_project_root(),
    legacy_ledger_path::AbstractString=joinpath(project_root, "specs", "ledger.toml"),
)
    return filter(
        check -> !check.ok,
        claim_ledger_checks(ledger_path; project_root=project_root, legacy_ledger_path=legacy_ledger_path),
    )
end

end
