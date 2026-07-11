using Test

@testset "v5.2 Lean formal statement smoke test" begin
    project_root = dirname(@__DIR__)
    statement = joinpath(project_root, "specs", "statements", "VP-V52-FORMAL-CORE-001.lean")
    @test isfile(statement)

    v52_files = [
        joinpath(project_root, "formal", "ERIEC", "Gate.lean"),
        joinpath(project_root, "formal", "ERIEC", "Gap.lean"),
        joinpath(project_root, "formal", "ERIEC", "Decay.lean"),
        joinpath(project_root, "formal", "ERIEC", "OpenSimC.lean"),
        joinpath(project_root, "formal", "ERIEC", "Centering.lean"),
        joinpath(project_root, "formal", "ERIEC", "Traceability.lean"),
        joinpath(project_root, "formal", "ERIEC", "RefModelV52.lean"),
    ]
    for file in v52_files
        @test isfile(file)
        text = read(file, String)
        @test !occursin(r"(?m)^\s*(sorry|axiom)\b", text)
    end

    # §23.2 is a CI/meta discipline: v5.2 discrete extensions must not gain a
    # direct import on the continuous World/Sensitivity bridge layer.
    forbidden_imports = [
        "ERIEC.Sensitivity",
        "ERIEC.World",
        "ERIEC.WorldDC",
    ]
    for file in v52_files
        text = read(file, String)
        for mod in forbidden_imports
            @test !occursin(Regex("(?m)^import\\s+$(replace(mod, "." => "\\\\."))\\b"), text)
        end
    end

    result = run(pipeline(
        setenv(`lake env lean $statement`, dir=project_root),
        stdout=devnull,
        stderr=devnull,
    ); wait=false)
    wait(result)
    @test success(result)
end
