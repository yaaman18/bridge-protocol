#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__, "..", "tools", "ClaimAudit.jl"))

function main(args)
    if length(args) == 3 && args[1] == "compare"
        left, right = (ClaimAudit.parse_claim_record(TOML.parsefile(path)) for path in args[2:3])
        TOML.print(stdout, ClaimAudit.compare_claim_records(left, right); sorted=true)
        return 0
    elseif length(args) in (2,3) && args[1] == "check"
        expected_digest = length(args) == 3 ? args[3] : nothing
        claim = ClaimAudit.parse_claim_record(TOML.parsefile(args[2]); expected_digest)
        TOML.print(stdout, Dict("valid_record" => true, "digest" => ClaimAudit.claim_record(claim)["digest"],
            "external_digest_checked" => expected_digest !== nothing,
            "phenomenal_claim" => "not_certified", "evidence_verified" => false); sorted=true)
        return 0
    end
    println(stderr, "Usage: julia --project=. bin/eriec-claim-audit.jl compare LEFT.toml RIGHT.toml")
    println(stderr, "       julia --project=. bin/eriec-claim-audit.jl check CLAIM.toml [EXPECTED_DIGEST]")
    2
end

try
    exit(main(ARGS))
catch err
    println(stderr, "Claim audit failed: ", sprint(showerror, err))
    exit(1)
end
