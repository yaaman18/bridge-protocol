using Test
using TOML

include(joinpath(@__DIR__, "..", "tools", "verify", "claim_ledger_validation.jl"))
using .ClaimLedgerValidation

@testset "claim ledger integrity" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    ledger_path = joinpath(project_root, "specs", "claim-ledger-v2.toml")
    checks = claim_ledger_checks(
        ledger_path;
        project_root=project_root,
    )
    # Guard against a vacuous pass: an empty or truncated check list would make
    # every assertion below disappear rather than fail.
    @test !isempty(checks)
    @test length(checks) >= 859
    @test any(check -> check.code == "LEGACY_COMPLETE_COVERAGE_MISSING" &&
        check.subject == "VP-BDY-003", checks)
    audited_ids = [row["legacy_vp_id"] for row in
        TOML.parsefile(joinpath(project_root, "specs", "ledger.toml"))["legacy_coverage"]]
    @test !isempty(audited_ids)
    for code in ("LEGACY_COVERAGE_REVIEWER_MISSING", "LEGACY_COVERAGE_EVIDENCE_MISSING")
        subjects = [check.subject for check in checks if check.code == code]
        @test sort(subjects) == sort(audited_ids)
    end
    for check in checks
        check.ok || @info "claim ledger violation" code=check.code subject=check.subject detail=check.detail
        @test check.ok
    end
end

@testset "claim validator enforces legacy coverage audits" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    ledger_path = joinpath(project_root, "specs", "claim-ledger-v2.toml")
    legacy_path = joinpath(project_root, "specs", "ledger.toml")
    original = read(legacy_path, String)
    baseline = TOML.parse(original)
    target_vp(ledger) = only(filter(vp -> vp["id"] == "VP-BDY-003", ledger["vp"]))
    target_row(ledger) = only(filter(row -> row["legacy_vp_id"] == "VP-BDY-003", ledger["legacy_coverage"]))

    mktempdir() do temporary_directory
        fixture = joinpath(temporary_directory, "ledger.toml")
        function violations_for(ledger)
            open(fixture, "w") do io
                TOML.print(io, ledger)
            end
            validate_claim_ledger(ledger_path; project_root=project_root, legacy_ledger_path=fixture)
        end

        @test isempty(violations_for(baseline))
        cases = (
            ("missing row", "LEGACY_COMPLETE_COVERAGE_MISSING",
                ledger -> filter!(row -> row["legacy_vp_id"] != "VP-BDY-003", ledger["legacy_coverage"])),
            ("missing coverage table", "LEGACY_COMPLETE_COVERAGE_MISSING",
                ledger -> delete!(ledger, "legacy_coverage")),
            ("duplicate row", "LEGACY_COVERAGE_IDS_NOT_UNIQUE",
                ledger -> push!(ledger["legacy_coverage"], deepcopy(target_row(ledger)))),
            ("unfinished row", "LEGACY_COMPLETE_COVERAGE_MISSING",
                ledger -> (target_row(ledger)["audit_status"] = "unreviewed")),
            ("wrong contract", "LEGACY_COVERAGE_CONTRACT_MISMATCH",
                ledger -> (target_row(ledger)["contract_id"] = "body.no_terminal_setpoint")),
            ("unknown VP", "LEGACY_COVERAGE_VP_UNKNOWN",
                ledger -> (target_row(ledger)["legacy_vp_id"] = "VP-UNKNOWN")),
            ("unfinished VP", "LEGACY_COMPLETE_VP_MISMATCH",
                ledger -> (target_vp(ledger)["coverage_audit"] = "unreviewed")),
            ("invalid audit value", "LEGACY_COVERAGE_AUDIT_INVALID",
                ledger -> (target_vp(ledger)["coverage_audit"] = "reviewed")),
            ("missing basis", "LEGACY_COVERAGE_BASIS_INVALID",
                ledger -> delete!(target_row(ledger), "basis")),
            ("missing reviewer", "LEGACY_COVERAGE_REVIEWER_MISSING",
                ledger -> delete!(target_row(ledger), "reviewer")),
            ("missing evidence field", "LEGACY_COVERAGE_EVIDENCE_MISSING",
                ledger -> delete!(target_row(ledger), "basis_log")),
            ("nonexistent evidence", "LEGACY_COVERAGE_EVIDENCE_MISSING",
                ledger -> (target_row(ledger)["basis_log"] = "logs/gates/missing-coverage-evidence.log")),
            ("missing VP table", "LEGACY_VPS_INVALID", ledger -> delete!(ledger, "vp")),
            ("empty VP table", "LEGACY_VPS_INVALID", ledger -> empty!(ledger["vp"])),
        )
        for (label, expected_code, mutate!) in cases
            @testset "$label" begin
                mutated = deepcopy(baseline)
                mutate!(mutated)
                violations = violations_for(mutated)
                @test !isempty(violations)
                @test expected_code in getfield.(violations, :code)
            end
        end
        @testset "evidence required for every audit row" begin
            rows = baseline["legacy_coverage"]
            @test !isempty(rows)
            @test Set(row["basis"] for row in rows) == Set(["exact_ledger_decl", "type_review"])
            for (index, row) in enumerate(rows)
                @testset "$(row["legacy_vp_id"]) ($(row["basis"]))" begin
                    for (label, expected_code, mutate_row!) in (
                        ("missing reviewer", "LEGACY_COVERAGE_REVIEWER_MISSING",
                            row -> delete!(row, "reviewer")),
                        ("blank reviewer", "LEGACY_COVERAGE_REVIEWER_MISSING",
                            row -> (row["reviewer"] = " ")),
                        ("missing basis_log", "LEGACY_COVERAGE_EVIDENCE_MISSING",
                            row -> delete!(row, "basis_log")),
                        ("blank basis_log", "LEGACY_COVERAGE_EVIDENCE_MISSING",
                            row -> (row["basis_log"] = "")),
                        ("nonexistent evidence file", "LEGACY_COVERAGE_EVIDENCE_MISSING",
                            row -> (row["basis_log"] = "logs/gates/missing-coverage-evidence.log")),
                        ("absolute evidence path", "LEGACY_COVERAGE_EVIDENCE_MISSING",
                            row -> (row["basis_log"] = abspath(joinpath(project_root, row["basis_log"])))),
                    )
                        @testset "$label" begin
                            mutated = deepcopy(baseline)
                            mutate_row!(mutated["legacy_coverage"][index])
                            violations = violations_for(mutated)
                            @test [(check.code, check.subject) for check in violations] ==
                                [(expected_code, row["legacy_vp_id"])]
                        end
                    end
                end
            end
        end
        missing = validate_claim_ledger(ledger_path;
            project_root=project_root,
            legacy_ledger_path=joinpath(temporary_directory, "missing.toml"))
        @test "LEGACY_LEDGER_MISSING" in getfield.(missing, :code)
        @test isempty(violations_for(baseline))
    end
    @test read(legacy_path, String) == original
end
