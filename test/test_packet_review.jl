using Test
using TOML

include(joinpath(@__DIR__, "..", "tools", "verify", "packet_review_validation.jl"))
using .PacketReviewValidation

@testset "packet review validation" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    packets_dir = joinpath(project_root, "specs", "packets")
    sidecars = sort(filter(path -> endswith(path, ".toml"), readdir(packets_dir; join=true)))
    @test !isempty(sidecars)
    for sidecar in sidecars
        checks = packet_review_checks(sidecar; project_root=project_root)
        @test !isempty(checks)
        @test isempty(filter(check -> !check.ok, checks))
    end

    fixture_dir = joinpath(@__DIR__, "fixtures", "packet_review")
    negative_cases = [
        "missing_id.toml" => "FM_REVIEW_MISSING_ID",
        "unknown_id.toml" => "FM_REVIEW_UNKNOWN_ID",
        "duplicate_id.toml" => "FM_REVIEW_DUPLICATE_ID",
        "rationale_missing.toml" => "FM_REVIEW_RATIONALE_MISSING",
        "mitigation_missing.toml" => "FM_REVIEW_MITIGATION_MISSING",
        "unknown_mutation.toml" => "FM_REVIEW_UNKNOWN_MUTATION",
        "prose_missing.toml" => "FM_REVIEW_PROSE_MISSING",
    ]
    for (fixture, expected_code) in negative_cases
        violations = validate_packet_review(
            joinpath(fixture_dir, fixture);
            project_root=project_root,
        )
        @test [violation.code for violation in violations] == [expected_code]
    end

    baseline_sidecar = first(sidecars)
    registry_path = joinpath(project_root, "specs", "verification-failure-modes.toml")
    registry = TOML.parsefile(registry_path)
    push!(registry["failure_mode"], Dict(
        "id" => "FM-SYNTHETIC-NEW-MODE",
        "title_ja" => "合成追加失敗様式",
        "description_ja" => "網羅検査の反証条件専用",
        "status" => "synthetic",
        "evidence_logs" => String[],
    ))
    mktempdir() do temporary_directory
        temporary_registry = joinpath(temporary_directory, "failure-modes.toml")
        open(temporary_registry, "w") do io
            TOML.print(io, registry)
        end
        violations = validate_packet_review(
            baseline_sidecar;
            project_root=project_root,
            registry_path=temporary_registry,
        )
        @test [violation.code for violation in violations] == ["FM_REVIEW_MISSING_ID"]
        @test violations[1].subject == "FM-SYNTHETIC-NEW-MODE"
    end

    mktempdir() do temporary_directory
        external_prose = joinpath(temporary_directory, "outside.md")
        write(external_prose, "outside repository")
        sidecar = TOML.parsefile(baseline_sidecar)
        sidecar["prose"] = external_prose
        external_sidecar = joinpath(temporary_directory, "external-prose.toml")
        open(external_sidecar, "w") do io
            TOML.print(io, sidecar)
        end
        violations = validate_packet_review(
            external_sidecar;
            project_root=project_root,
        )
        @test [violation.code for violation in violations] == ["FM_REVIEW_PROSE_MISSING"]
    end

    mktempdir() do temporary_directory
        real_root = joinpath(temporary_directory, "repository")
        linked_root = joinpath(temporary_directory, "repository-link")
        mkpath(joinpath(real_root, "specs", "packets"))
        mkpath(joinpath(real_root, "tools"))
        cp(
            joinpath(project_root, "specs", "verification-failure-modes.toml"),
            joinpath(real_root, "specs", "verification-failure-modes.toml"),
        )
        cp(
            joinpath(project_root, "tools", "mutation_corpus.toml"),
            joinpath(real_root, "tools", "mutation_corpus.toml"),
        )
        write(joinpath(real_root, "specs", "packet.md"), "synthetic packet")
        sidecar = TOML.parsefile(baseline_sidecar)
        sidecar["prose"] = "specs/packet.md"
        sidecar_path = joinpath(real_root, "specs", "packets", "packet.toml")
        open(sidecar_path, "w") do io
            TOML.print(io, sidecar)
        end
        symlink(real_root, linked_root)

        violations = validate_packet_review(
            joinpath(linked_root, "specs", "packets", "packet.toml");
            project_root=linked_root,
        )
        @test isempty(violations)

        external_prose = joinpath(temporary_directory, "outside.md")
        write(external_prose, "outside repository")
        symlink(external_prose, joinpath(real_root, "specs", "external.md"))
        sidecar["prose"] = "specs/external.md"
        external_sidecar = joinpath(real_root, "specs", "packets", "external.toml")
        open(external_sidecar, "w") do io
            TOML.print(io, sidecar)
        end
        violations = validate_packet_review(
            joinpath(linked_root, "specs", "packets", "external.toml");
            project_root=linked_root,
        )
        @test [violation.code for violation in violations] == ["FM_REVIEW_PROSE_MISSING"]
    end
end
