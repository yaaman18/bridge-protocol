using Test

# RSB-001 §8(1): the registry suite runs in its own minimal project so that ERIEC is not on
# its load path. This root-side test only launches that subprocess.
@testset "RSB-001 substrate registry (isolated subprocess)" begin
    project = normpath(joinpath(@__DIR__, "..", "tools", "SubstrateRegistry"))
    cmd = addenv(`$(Base.julia_cmd()) --startup-file=no --project=$project
        $(joinpath(project, "test", "runtests.jl"))`, "JULIA_LOAD_PATH" => "@:@stdlib")
    @test success(pipeline(cmd; stdout=stdout, stderr=stderr))
end
