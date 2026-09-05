using Test

include(joinpath(@__DIR__, "..", "tools", "verify", "g3c_evidence_validation.jl"))
using .G3CEvidenceValidation

@testset "G3C committed evidence validation" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    evidence_commit = "98ec648425be2786b1a1dda438e94a61ecdfc875"
    evidence_log = "logs/gates/G3C-v2/G3C-20260904-final-dirty-snapshot.log"
    @test isempty(validate_g3c_evidence(
        evidence_log,
        evidence_commit;
        project_root,
    ))

    log_text = read(
        Cmd([
            "git",
            "-C",
            project_root,
            "show",
            "$evidence_commit:$evidence_log",
        ]),
        String,
    )

    missing_cleanup = replace(
        log_text,
        "G3C_CLONE_DESTROYED=true\n" => "";
        count=1,
    )
    missing_failures = G3CEvidenceValidation.failures(g3c_evidence_text_checks(
        missing_cleanup,
        evidence_commit;
        project_root,
    ))
    @test "G3C_REQUIRED_MARKER" in getfield.(missing_failures, :code)

    conflicting_result = replace(
        log_text,
        "G3C_RESULT=PASS" => "G3C_RESULT=PASS\nG3C_RESULT=FAIL";
        count=1,
    )
    conflicting_failures = G3CEvidenceValidation.failures(g3c_evidence_text_checks(
        conflicting_result,
        evidence_commit;
        project_root,
    ))
    @test "G3C_SINGLE_VALUE" in getfield.(conflicting_failures, :code)

    wrong_digest = replace(
        log_text,
        r"G3C_TEST_INPUT_DIGEST=[0-9a-f]+" =>
            "G3C_TEST_INPUT_DIGEST=$(repeat("0", 40))";
        count=1,
    )
    digest_failures = G3CEvidenceValidation.failures(g3c_evidence_text_checks(
        wrong_digest,
        evidence_commit;
        project_root,
    ))
    @test "G3C_INPUT_DIGEST_MATCH" in getfield.(digest_failures, :code)

    missing_dependency = replace(
        log_text,
        r"path=\.\./proof-carrying-intersubjectivity[^\n]+\n" => "";
        count=1,
    )
    dependency_failures = G3CEvidenceValidation.failures(g3c_evidence_text_checks(
        missing_dependency,
        evidence_commit;
        project_root,
    ))
    @test "G3C_PATH_DEPENDENCY_SET" in getfield.(dependency_failures, :code)

    wrong_dependency_head = replace(
        log_text,
        r"head=[0-9a-f]{40}" => "head=$(repeat("0", 40))";
        count=1,
    )
    dependency_object_failures = G3CEvidenceValidation.failures(g3c_evidence_text_checks(
        wrong_dependency_head,
        evidence_commit;
        project_root,
    ))
    @test "G3C_PATH_DEPENDENCY_OBJECT" in getfield.(dependency_object_failures, :code)

    @test [failure.code for failure in validate_g3c_evidence(
        "../outside.log",
        evidence_commit;
        project_root,
    )] == ["G3C_LOG_PATH"]
    @test [failure.code for failure in validate_g3c_evidence(
        evidence_log,
        evidence_commit[1:12];
        project_root,
    )] == ["G3C_COMMIT"]
end

@testset "G3C status-only transition validation" begin
    run_git(root, arguments...) = run(Cmd(vcat(["git", "-C", root], collect(arguments))))
    git_text(root, arguments...) = strip(read(
        Cmd(vcat(["git", "-C", root], collect(arguments))),
        String,
    ))

    mktempdir() do repository
        run_git(repository, "init", "--quiet")
        run_git(repository, "config", "user.name", "G3C Test")
        run_git(repository, "config", "user.email", "g3c-test@invalid.local")
        mkpath(joinpath(repository, "specs"))
        write(
            joinpath(repository, "specs", "ledger.toml"),
            """
            [[vp]]
            id = "VP-TEST-001"
            lean_decl = "ERIEC.Test.claim"
            status = "bound"
            """,
        )
        run_git(repository, "add", "specs/ledger.toml")
        run_git(repository, "commit", "--quiet", "-m", "evidence")
        evidence = git_text(repository, "rev-parse", "HEAD")

        write(
            joinpath(repository, "specs", "ledger.toml"),
            """
            # G3C: committed evidence
            [[vp]]
            id = "VP-TEST-001"
            lean_decl = "ERIEC.Test.claim"
            status = "implemented"
            """,
        )
        run_git(repository, "add", "specs/ledger.toml")
        run_git(repository, "commit", "--quiet", "-m", "status transition")
        transition = git_text(repository, "rev-parse", "HEAD")

        @test isempty(validate_g3c_transition(
            evidence,
            transition,
            "VP-TEST-001";
            project_root=repository,
        ))

        write(joinpath(repository, "implementation.jl"), "changed = true\n")
        run_git(repository, "add", "implementation.jl")
        run_git(repository, "commit", "--quiet", "-m", "implementation mutation")
        mutated = git_text(repository, "rev-parse", "HEAD")
        violations = validate_g3c_transition(
            transition,
            mutated,
            "VP-TEST-001";
            project_root=repository,
        )
        @test "G3C_TRANSITION_CHANGED_PATHS" in getfield.(violations, :code)
    end
end
