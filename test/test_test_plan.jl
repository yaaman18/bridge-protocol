using Test

module TestPlanAuditFixture
include("parallel_test_plan.jl")
end

@testset "test discovery is checked before scheduling" begin
    validate = TestPlanAuditFixture.validate_eriec_test_plan
    @test validate()
    mktempdir() do dir
        write(joinpath(dir, "test_registered.jl"), "")
        plan = [("test_registered.jl", 0.5)]
        @test validate(dir, plan)
        write(joinpath(dir, "test_forgotten.jl"), "")
        @test_throws r"omits test files: test_forgotten.jl" validate(dir, plan)
        push!(plan, ("test_forgotten.jl", 0.5))
        @test validate(dir, plan)
        @test_throws r"duplicate files" validate(dir, [plan; plan])
        rm(joinpath(dir, "test_registered.jl"))
        @test_throws r"missing files: test_registered.jl" validate(dir, plan)
    end
end
