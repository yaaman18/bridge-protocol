using SHA
using TOML
using Test

@testset "claim ledger integrity" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    ledger = TOML.parsefile(joinpath(project_root, "specs", "claim-ledger-v2.toml"))
    claims = ledger["claim"]
    groups = ledger["claim_group"]
    defaults = ledger["defaults"]

    claim_ids = [claim["id"] for claim in claims]
    @test allunique(claim_ids)
    claims_by_id = Dict(claim["id"] => claim for claim in claims)
    catalog_text = read(
        joinpath(project_root, "formal", "ERIEC", "CertifiedArtifact.lean"),
        String,
    )

    for group in groups
        @test all(child -> haskey(claims_by_id, child), group["children"])
        if group["coverage"] == "complete"
            @test all(
                child -> get(claims_by_id[child], "spec_status", defaults["spec_status"]) ==
                    "frozen",
                group["children"],
            )
        end
    end

    for claim in claims
        @test isfile(joinpath(project_root, claim["lean_file"]))
        if haskey(claim, "statement_spec")
            statement_path = joinpath(project_root, claim["statement_spec"])
            @test isfile(statement_path)
            actual_hash = "sha256:" * bytes2hex(sha256(read(statement_path)))
            @test actual_hash == claim["statement_hash"]
        end
        if get(claim, "proof_status", defaults["proof_status"]) == "unproved"
            @test claim["claim_kind"] == "conjecture"
            @test claim["checker_relation"] == "observation_only"
        end
        if haskey(claim, "contract_id")
            @test get(
                claim,
                "certification_status",
                defaults["certification_status"],
            ) == "certified"
            @test occursin("id := \"$(claim["contract_id"])\"", catalog_text)
            @test isfile(joinpath(project_root, claim["certification_log"]))
        end
    end
end
