using TOML
using Test

@testset "v1 ledger coverage audit" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    ledger = TOML.parsefile(joinpath(project_root, "specs", "ledger.toml"))
    allowed_coverage_audits = Set(["unreviewed", "complete"])

    for vp in ledger["vp"]
        if vp["status"] == "certified"
            @test haskey(vp, "coverage_audit")
            @test get(vp, "coverage_audit", nothing) in allowed_coverage_audits
        end
    end
end
