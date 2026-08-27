using Test

include(joinpath(@__DIR__, "..", "tools", "verify", "claim_ledger_validation.jl"))
using .ClaimLedgerValidation

@testset "claim ledger integrity" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    ledger_path = joinpath(project_root, "specs", "claim-ledger-v2.toml")
    checks = claim_ledger_checks(
        ledger_path;
        project_root=project_root,
    )
    for check in checks
        check.ok || @info "claim ledger violation" code=check.code subject=check.subject detail=check.detail
        @test check.ok
    end
end
