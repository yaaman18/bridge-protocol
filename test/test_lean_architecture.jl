using Test

@testset "Lean module architecture" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    formal_root = joinpath(project_root, "formal", "ERIEC")
    lean_files = filter(
        path -> endswith(path, ".lean"),
        collect(Iterators.flatten(
            (joinpath(root, file) for file in files) for (root, _, files) in walkdir(formal_root)
        )),
    )

    broad_mathlib_imports = String[]
    forbidden_experiment_imports = String[]
    for path in lean_files
        for line in eachline(path)
            stripped = strip(line)
            stripped == "import Mathlib" && push!(broad_mathlib_imports, path)
            occursin(r"^import (Scratch|Experiments|Draft|Attempt)(\.|$)", stripped) &&
                push!(forbidden_experiment_imports, path)
        end
    end
    @test isempty(broad_mathlib_imports)
    @test isempty(forbidden_experiment_imports)

    expected_invariance_imports = Dict(
        "Invariance.lean" => [
            "ERIEC.Invariance.Dynamic",
            "ERIEC.Invariance.Spectral",
            "ERIEC.Invariance.External",
        ],
        "Invariance/Basic.lean" => ["ERIEC.Hinge"],
        "Invariance/Lemmas.lean" => ["ERIEC.Invariance.Basic"],
        "Invariance/Static.lean" => ["ERIEC.Invariance.Lemmas"],
        "Invariance/Dynamic.lean" => ["ERIEC.Invariance.Static", "ERIEC.Dynamics"],
        "Invariance/Spectral.lean" => ["ERIEC.World"],
        "Invariance/External.lean" => String[],
    )
    for (relative_path, expected) in expected_invariance_imports
        path = joinpath(formal_root, relative_path)
        imports = [split(strip(line), limit=2)[2] for line in eachline(path)
                   if startswith(strip(line), "import ")]
        @test imports == expected
    end

    experiment_root = realpath(joinpath(project_root, "formal-experiments"))
    @test startswith(relpath(experiment_root, realpath(joinpath(project_root, "formal"))), "..")
    entrypoint = read(joinpath(project_root, "formal", "ERIEC.lean"), String)
    @test !occursin(r"(?m)^import (Scratch|Experiments|Draft|Attempt)(\.|$)", entrypoint)
end
