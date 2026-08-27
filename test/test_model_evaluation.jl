using JSON3
using SHA
using Test
using ERIEC

digest(path) = bytes2hex(SHA.sha256(read(path)))

function rewrite_json_and_seal!(edit!, artifact_path::AbstractString, seal_name::AbstractString)
    payload = JSON3.read(read(artifact_path, String), Dict{String,Any})
    edit!(payload)
    bytes = Vector{UInt8}(codeunits(String(JSON3.write(payload)) * "\n"))
    write(artifact_path, bytes)
    write(
        joinpath(dirname(artifact_path), "seal.sha256"),
        "$(bytes2hex(SHA.sha256(bytes)))  $seal_name\n",
    )
    artifact_path
end

@testset "M4 model schema and canonical fingerprint input" begin
    @test MODEL_EVALUATION_SCHEMA_VERSION == 3
    @test COUNTEREXAMPLE_DRAFT_SCHEMA_VERSION == 1
    unordered = """{"kind":"set_point_diagram_model","schema_version":1,"contract_id":"body.no_terminal_setpoint","carrier_complete":true,"relation_encoding":"closed_world_edge_list","objects":["b","a"],"reaches":[["b","a"],["a","b"]],"claim_status":"not_a_claim","phenomenal_claim":"not_certified"}"""
    model = parse_m4_setpoint_model_json(unordered)
    @test model.objects == ("a", "b")
    @test model.reaches == (("a", "b"), ("b", "a"))
    @test m4_setpoint_model_json(model) == m4_setpoint_model_json(
        M4SetPointModel(["a", "b"], [("a", "b"), ("b", "a")]),
    )
    canonical = m4_setpoint_model_json(model)
    @test bytes2hex(SHA.sha256(codeunits(canonical))) == bytes2hex(SHA.sha256(
        codeunits(m4_setpoint_model_json(parse_m4_setpoint_model_json("  $unordered\n"))),
    ))
    @test check_m4_no_terminal_setpoint(m4_setpoint_diagram(
        M4SetPointModel(["only"], Tuple{String,String}[]),
    ))
    @test !check_m4_no_terminal_setpoint(m4_setpoint_diagram(
        M4SetPointModel(["only"], [("only", "only")]),
    ))
    dispatch_probe = m4_setpoint_diagram(
        M4SetPointModel(["dispatch"], Tuple{String,String}[]),
    )
    dispatch_probe_type = typeof(dispatch_probe)
    @eval ERIEC check_m4_no_terminal_setpoint(
        diagram::$dispatch_probe_type,
    ) = false
    injected_method = which(
        check_m4_no_terminal_setpoint,
        Tuple{dispatch_probe_type},
    )
    try
        @test_throws ArgumentError ERIEC._model_evaluation_registered_checker(
            "check_m4_no_terminal_setpoint",
            dispatch_probe,
        )
    finally
        Base.delete_method(injected_method)
    end
    @test ERIEC._model_evaluation_registered_checker(
        "check_m4_no_terminal_setpoint",
        dispatch_probe,
    )
    raw_probe = Vector{UInt8}(codeunits(m4_setpoint_model_json(
        M4SetPointModel(["adapter"], Tuple{String,String}[]),
    )))
    @eval ERIEC _decode_model_evaluation_adapter(
        adapter_id::String,
        bytes::Vector{UInt8},
    ) = error("injected adapter method")
    injected_adapter_method = which(
        ERIEC._decode_model_evaluation_adapter,
        Tuple{String,Vector{UInt8}},
    )
    try
        decoded_probe = ERIEC._model_evaluation_decode_registered_adapter(
            "m4-setpoint-model-v1",
            raw_probe,
        )
        @test decoded_probe.decoded.objects == ("adapter",)
    finally
        Base.delete_method(injected_adapter_method)
    end

    unknown = replace(unordered, r"}$" => ",\"extra\":true}")
    duplicate_field = replace(
        unordered,
        "{\"kind\":" => "{\"kind\":\"wrong\",\"kind\":";
        count=1,
    )
    dangling = replace(unordered, "[\"b\",\"a\"]" => "[\"missing\",\"a\"]")
    non_string_object = replace(unordered, "[\"b\",\"a\"]" => "[1,\"a\"]")
    short_edge = replace(unordered, "[\"b\",\"a\"]" => "[\"b\"]")
    duplicate_edge = replace(
        unordered,
        "[[\"b\",\"a\"],[\"a\",\"b\"]]" =>
            "[[\"b\",\"a\"],[\"b\",\"a\"]]",
    )
    marker_type = replace(
        unordered,
        "\"phenomenal_claim\":\"not_certified\"" => "\"phenomenal_claim\":false",
    )
    @test_throws ArgumentError parse_m4_setpoint_model_json(unknown)
    @test_throws ArgumentError parse_m4_setpoint_model_json(duplicate_field)
    @test_throws ArgumentError parse_m4_setpoint_model_json(dangling)
    @test_throws ArgumentError parse_m4_setpoint_model_json(non_string_object)
    @test_throws ArgumentError parse_m4_setpoint_model_json(short_edge)
    @test_throws ArgumentError parse_m4_setpoint_model_json(duplicate_edge)
    @test_throws ArgumentError parse_m4_setpoint_model_json(marker_type)
    @test_throws ArgumentError M4SetPointModel(["bad/id"], Tuple{String,String}[])
    @test_throws ArgumentError M4SetPointModel(["trailing-newline\n"], Tuple{String,String}[])
    @test_throws ArgumentError M4SetPointModel(["same", "same"], Tuple{String,String}[])
    mktempdir() do directory
        dangling = joinpath(directory, "dangling-model.json")
        symlink(joinpath(directory, "missing.json"), dangling)
        @test_throws ArgumentError write_m4_setpoint_model(
            dangling,
            M4SetPointModel(["only"], Tuple{String,String}[]);
            overwrite=true,
        )
        @test islink(dangling)
    end
    @test_throws ArgumentError model_evaluation_path(
        mktempdir(),
        "trailing-newline\n",
    )
    @test_throws ArgumentError ERIEC._model_evaluation_hash(
        repeat("a", 64) * "\n",
        "test digest",
    )

    examples = joinpath(@__DIR__, "..", "examples", "model-evaluations")
    example_pass = parse_m4_setpoint_model_json(read(
        joinpath(examples, "m4-one-state-pass.json"),
        String,
    ))
    example_reject = parse_m4_setpoint_model_json(read(
        joinpath(examples, "m4-one-state-reject.json"),
        String,
    ))
    @test check_m4_no_terminal_setpoint(m4_setpoint_diagram(example_pass))
    @test !check_m4_no_terminal_setpoint(m4_setpoint_diagram(example_reject))
end

@testset "model evaluation CLI" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    mktempdir() do evidence_root
        model_path = write_m4_setpoint_model(
            joinpath(evidence_root, "models", "reject.json"),
            M4SetPointModel(["only"], [("only", "only")]),
        )
        pass_model_path = write_m4_setpoint_model(
            joinpath(evidence_root, "models", "pass.json"),
            M4SetPointModel(["only"], Tuple{String,String}[]),
        )
        out = IOBuffer()
        err = IOBuffer()
        exit_code = model_evaluation_cli(
            [
                "run",
                "--root", evidence_root,
                "--model", model_path,
                "--evaluation-id", "cli-reject",
                "--counterexample-candidate",
            ];
            project_root=project_root,
            out=out,
            err=err,
        )
        @test exit_code == 0
        run_payload = JSON3.read(String(take!(out)))
        @test String(run_payload.outcome) == "reject"
        @test String(run_payload.claim_relation) == "counterexample_candidate"
        @test isempty(String(take!(err)))

        relative_root = relpath(evidence_root, pwd())
        @test model_evaluation_cli(
            [
                "run",
                "--root", relative_root,
                "--model", relpath(pass_model_path, evidence_root),
                "--evaluation-id", "cli-pass",
            ];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        @test String(JSON3.read(String(take!(out))).outcome) == "pass"

        @test model_evaluation_cli(
            ["audit", "--root", evidence_root, "--evaluation-id", "cli-reject"];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        @test JSON3.read(String(take!(out))).ok === true

        @test model_evaluation_cli(
            ["list", "--root", evidence_root, "--outcome", "reject"];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        list_payload = JSON3.read(String(take!(out)))
        @test list_payload.count == 1

        @test model_evaluation_cli(
            [
                "list",
                "--root", evidence_root,
                "--vp-id", "VP-BDY-001",
                "--contract-id", "body.no_terminal_setpoint",
                "--counterexample-candidates",
            ];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        @test JSON3.read(String(take!(out))).count == 1

        @test model_evaluation_cli(
            ["draft", "--root", evidence_root, "--evaluation-id", "cli-reject"];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        draft_payload = JSON3.read(String(take!(out)))
        @test draft_payload.automatic_promotion === false

        @test model_evaluation_cli(
            ["draft-list", "--root", evidence_root];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        draft_list_payload = JSON3.read(String(take!(out)))
        @test draft_list_payload.count == 1
        @test String(only(draft_list_payload.entries).evaluation_id) == "cli-reject"

        @test model_evaluation_cli(
            [
                "draft-audit",
                "--root", evidence_root,
                "--evaluation-id", "cli-reject",
            ];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        @test JSON3.read(String(take!(out))).ok === true
        @test model_evaluation_cli(
            ["draft-audit", "--root", evidence_root];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        @test JSON3.read(String(take!(out))).checked == 1

        mktempdir() do alias_parent
            alias_root = joinpath(alias_parent, "evidence-alias")
            symlink(evidence_root, alias_root)
            @test model_evaluation_cli(
                [
                    "run",
                    "--root", alias_root,
                    "--model", pass_model_path,
                    "--evaluation-id", "cli-alias-root",
                ];
                project_root=project_root,
                out=out,
                err=err,
            ) == 0
            alias_payload = JSON3.read(String(take!(out)))
            artifact = String(alias_payload.artifact)
            @test artifact == joinpath(
                "logs",
                "model-evaluations",
                "cli-alias-root",
                "evaluation.json",
            )
            @test !startswith(artifact, "..")
            @test isfile(joinpath(evidence_root, artifact))
        end

        malformed_path = joinpath(evidence_root, "models", "malformed.json")
        write(malformed_path, "{\"kind\":\"set_point_diagram_model\"}\n")
        @test model_evaluation_cli(
            [
                "run",
                "--root", evidence_root,
                "--model", malformed_path,
                "--evaluation-id", "cli-error",
            ];
            project_root=project_root,
            out=out,
            err=err,
        ) == 1
        error_run_payload = JSON3.read(String(take!(out)))
        @test String(error_run_payload.outcome) == "error"
        @test audit_model_evaluation(
            evidence_root,
            "cli-error";
            project_root=project_root,
        ).ok
        @test model_evaluation_cli(
            ["audit", "--root", evidence_root];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        aggregate_payload = JSON3.read(String(take!(out)))
        @test aggregate_payload.ok === true
        @test aggregate_payload.checked == 4

        @test model_evaluation_cli(
            ["list", "--root", evidence_root, "--outcome", "unknown"];
            project_root=project_root,
            out=out,
            err=err,
        ) == 2
        error_payload = JSON3.read(String(take!(err)))
        @test String(error_payload.kind) == "model_evaluation_cli_error"

        missing_root = joinpath(evidence_root, "does-not-exist")
        @test model_evaluation_cli(
            ["audit", "--root", missing_root];
            project_root=project_root,
            out=out,
            err=err,
        ) == 1
        @test JSON3.read(String(take!(out))).ok === false

        @test model_evaluation_cli(
            String[];
            project_root=project_root,
            out=out,
            err=err,
        ) == 2
        @test String(JSON3.read(String(take!(err))).kind) ==
            "model_evaluation_cli_error"

        for bad_args in (
            ["unknown"],
            ["run", "--model"],
            ["audit", "--root", evidence_root, "--root", evidence_root],
            ["list", "--root", ""],
        )
            @test model_evaluation_cli(
                bad_args;
                project_root=project_root,
                out=out,
                err=err,
            ) == 2
            @test String(JSON3.read(String(take!(err))).kind) ==
                "model_evaluation_cli_error"
        end

        @test model_evaluation_cli(
            ["run", "--help"];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        @test occursin("Usage:", String(take!(out)))

        @test model_evaluation_cli(
            ["--help"];
            project_root=project_root,
            out=out,
            err=err,
        ) == 0
        @test occursin("Usage:", String(take!(out)))

        bin_path = joinpath(project_root, "bin", "eriec-model-evaluation.jl")
        bin_help = read(
            Cmd(`$(Base.julia_cmd()) --project=$project_root $bin_path --help`; dir=project_root),
            String,
        )
        @test occursin("Usage:", bin_help)
    end
end

@testset "append-only model evaluation execution and audit" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    claim_ledger = joinpath(project_root, "specs", "claim-ledger-v2.toml")
    claim_ledger_before = digest(claim_ledger)

    mktempdir() do evidence_root
        models = joinpath(evidence_root, "models")
        mkpath(models)
        pass_source = write_m4_setpoint_model(
            joinpath(models, "one-state-pass.json"),
            M4SetPointModel(["only"], Tuple{String,String}[]),
        )
        reject_source = write_m4_setpoint_model(
            joinpath(models, "one-state-reject.json"),
            M4SetPointModel(["only"], [("only", "only")]),
        )

        passed = run_m4_model_evaluation(
            project_root,
            pass_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="one-state-pass",
        )
        @test passed.record.outcome == :pass
        @test passed.record.claim_relation == :observation_only
        @test passed.record.checker_relation == "exact_finite_decision"
        @test passed.record.lean_decl == "ERIEC.Body.NoTerminalSetPoint"
        @test passed.record.adapter_id == "m4-setpoint-model-v1"
        @test passed.record.adapter_source_origin == "src/m4_model_evaluation.jl"
        @test isfile(joinpath(evidence_root, passed.record.adapter_source))
        @test passed.record.phenomenal_claim == :not_certified
        @test read_model_evaluation(passed.path).evaluation_id == "one-state-pass"
        legacy_payload = JSON3.read(
            model_evaluation_json(passed.record),
            Dict{String,Any},
        )
        legacy_payload["schema_version"] = 2
        delete!(legacy_payload, "error_stage")
        delete!(legacy_payload, "error_diagnostics")
        legacy_record = parse_model_evaluation_json(String(JSON3.write(legacy_payload)))
        @test legacy_record.schema_version == 2
        @test Set(String.(keys(JSON3.read(model_evaluation_json(legacy_record))))) ==
            ERIEC._MODEL_EVALUATION_PAYLOAD_KEYS_V2
        passed_audit = audit_model_evaluation(
            evidence_root,
            "one-state-pass";
            project_root=project_root,
        )
        @test passed_audit.ok
        @test passed_audit.semantic_replay == :passed
        registry = JSON3.read(read(
            joinpath(evidence_root, passed.record.registry_snapshot),
            String,
        ))
        @test String(registry.review_status) == "reviewed"
        @test !isempty(String(registry.reviewer))
        @test !isempty(String(registry.basis_log))
        @test occursin(
            r"^[0-9a-f]{64}\z",
            String(registry.lean_declaration_source_sha256),
        )
        @test occursin(
            r"^[0-9a-f]{64}\z",
            String(registry.registry_generation_sha256),
        )
        @test String(registry.registry_git_commit) == passed.record.git_commit

        # The source may disappear; the evaluation remains reconstructible from snapshots.
        rm(pass_source)
        removed_source_audit = audit_model_evaluation(
            evidence_root,
            "one-state-pass";
            project_root=project_root,
        )
        @test removed_source_audit.ok
        @test removed_source_audit.semantic_replay == :passed

        duplicate_source = write_m4_setpoint_model(
            joinpath(models, "same-canonical-model.json"),
            M4SetPointModel(["only"], Tuple{String,String}[]),
        )
        duplicate = run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="one-state-pass-again",
            claim_relation=:counterexample_candidate,
        )
        @test duplicate.record.model_fingerprint == passed.record.model_fingerprint
        @test duplicate.record.claim_relation == :observation_only
        @test_throws ArgumentError run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="one-state-pass",
        )

        rejected = run_m4_model_evaluation(
            project_root,
            reject_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="one-state-reject",
            claim_relation=:counterexample_candidate,
        )
        @test rejected.record.outcome == :reject
        @test rejected.record.failed_predicates == ["ERIEC.Body.NoTerminalSetPoint"]
        @test rejected.record.claim_relation == :counterexample_candidate

        rejected_observation = run_m4_model_evaluation(
            project_root,
            reject_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="one-state-reject-observation",
        )
        @test rejected_observation.record.outcome == :reject
        @test rejected_observation.record.claim_relation == :observation_only

        malformed_source = joinpath(models, "dangling-edge.json")
        write(
            malformed_source,
            """{"kind":"set_point_diagram_model","schema_version":1,"contract_id":"body.no_terminal_setpoint","carrier_complete":true,"relation_encoding":"closed_world_edge_list","objects":["only"],"reaches":[["only","missing"]],"claim_status":"not_a_claim","phenomenal_claim":"not_certified"}\n""",
        )
        malformed = run_m4_model_evaluation(
            project_root,
            malformed_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="malformed-input",
            claim_relation=:counterexample_candidate,
        )
        @test malformed.record.outcome == :error
        @test malformed.record.error_stage == :input_schema
        @test isempty(malformed.record.failed_predicates)
        @test malformed.record.error_message !== nothing
        @test malformed.record.claim_relation == :observation_only
        @test audit_model_evaluation(
            evidence_root,
            "malformed-input";
            project_root=project_root,
        ).ok

        empty_source = joinpath(models, "empty.json")
        write(empty_source, UInt8[])
        empty_input = run_m4_model_evaluation(
            project_root,
            empty_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="empty-input",
        )
        @test empty_input.record.outcome == :error
        @test empty_input.record.error_stage == :input_schema
        @test audit_model_evaluation(
            evidence_root,
            "empty-input";
            project_root=project_root,
        ).ok

        invalid_utf8_source = joinpath(models, "invalid-utf8.json")
        write(invalid_utf8_source, UInt8[0xff])
        invalid_utf8 = run_m4_model_evaluation(
            project_root,
            invalid_utf8_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="invalid-utf8-input",
        )
        @test invalid_utf8.record.outcome == :error
        @test invalid_utf8.record.error_stage == :input_schema
        @test isvalid(something(invalid_utf8.record.error_message, ""))
        @test isvalid(read(invalid_utf8.path, String))
        invalid_utf8_audit = audit_model_evaluation(
            evidence_root,
            "invalid-utf8-input";
            project_root=project_root,
        )
        @test invalid_utf8_audit.ok
        @test invalid_utf8_audit.semantic_replay == :passed

        @test_throws ArgumentError run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="invalid-claim-relation",
            claim_relation=:bogus,
        )
        @test !ispath(model_evaluation_path(evidence_root, "invalid-claim-relation"))

        automatic_first = run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
        )
        automatic_second = run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
        )
        @test automatic_first.record.evaluation_id != automatic_second.record.evaluation_id
        @test isfile(automatic_first.path)
        @test isfile(automatic_second.path)

        # Model preparation is registry-dispatched; callers cannot inject an
        # arbitrary value/canonical-byte pair through the private primitive.
        @test_throws MethodError ERIEC._run_model_evaluation(
            project_root;
            output_root=evidence_root,
            evaluation_id="arbitrary-prepare-model",
            raw_model_bytes=read(duplicate_source),
            prepare_model=_ -> error("must never run"),
            vp_id="VP-BDY-001",
            contract_id="body.no_terminal_setpoint",
            checker_id="check_m4_no_terminal_setpoint",
            failed_predicates_on_reject=["ERIEC.Body.NoTerminalSetPoint"],
            adapter_id="m4-setpoint-model-v1",
        )
        @test !ispath(model_evaluation_path(evidence_root, "arbitrary-prepare-model"))

        evaluation_text = read(invalid_utf8.path, String)
        unknown_evaluation_field = replace(
            strip(evaluation_text),
            r"}$" => ",\"unknown_field\":true}",
        )
        @test_throws ArgumentError parse_model_evaluation_json(unknown_evaluation_field)

        candidates = list_model_evaluations(
            evidence_root;
            project_root=project_root,
            counterexample_candidates=true,
        )
        @test only(candidates).evaluation_id == "one-state-reject"
        rejected_only = list_model_evaluations(
            evidence_root;
            project_root=project_root,
            outcome=:reject,
        )
        @test Set(entry.evaluation_id for entry in rejected_only) ==
            Set(["one-state-reject", "one-state-reject-observation"])
        aggregate = audit_model_evaluations(evidence_root; project_root=project_root)
        @test aggregate.ok
        @test aggregate.checked == 9
        @test aggregate.semantic_replay_complete
        @test aggregate.semantic_replay_counts == (
            passed=9,
            failed=0,
            skipped=0,
            not_attempted=0,
        )
        duplicate_group = only(filter(
            group -> group.model_fingerprint == passed.record.model_fingerprint,
            aggregate.duplicate_fingerprints,
        ))
        @test Set(duplicate_group.evaluation_ids) ==
            Set([
                "one-state-pass",
                "one-state-pass-again",
                automatic_first.record.evaluation_id,
                automatic_second.record.evaluation_id,
            ])

        candidate_parent = joinpath(
            evidence_root,
            "logs",
            "counterexample-candidates",
        )
        mktempdir() do escaped_candidates
            symlink(escaped_candidates, candidate_parent)
            @test_throws ArgumentError write_counterexample_draft_packet(
                evidence_root,
                "one-state-reject";
                project_root=project_root,
            )
            @test isempty(readdir(escaped_candidates))
            rm(candidate_parent)
        end
        packet_path = write_counterexample_draft_packet(
            evidence_root,
            "one-state-reject";
            project_root=project_root,
        )
        packet = JSON3.read(read(packet_path, String))
        @test String(packet.claim_status) == "draft_not_a_claim"
        @test packet.automatic_promotion === false
        @test String(packet.phenomenal_claim) == "not_certified"
        @test packet.target_claim_id === nothing
        parsed_packet = read_counterexample_draft(packet_path)
        @test parsed_packet.evaluation_id == "one-state-reject"
        @test parsed_packet.claim_status == :draft_not_a_claim
        @test parsed_packet.phenomenal_claim == :not_certified
        packet_audit = audit_counterexample_draft(
            evidence_root,
            "one-state-reject";
            project_root=project_root,
        )
        @test packet_audit.ok
        @test packet_audit.semantic_replay == :passed
        packet_entries = list_counterexample_drafts(
            evidence_root;
            project_root=project_root,
        )
        @test length(packet_entries) == 1
        @test only(packet_entries).audit_ok
        packet_aggregate = audit_counterexample_drafts(
            evidence_root;
            project_root=project_root,
        )
        @test packet_aggregate.ok
        @test packet_aggregate.checked == 1
        @test digest(claim_ledger) == claim_ledger_before
        @test_throws ArgumentError write_counterexample_draft_packet(
            evidence_root,
            "one-state-pass";
            project_root=project_root,
        )
        @test_throws ArgumentError write_counterexample_draft_packet(
            evidence_root,
            "one-state-reject";
            project_root=project_root,
        )

        # Even with all persisted hashes and the evaluation seal recomputed,
        # a valid raw model must canonicalize to the recorded model snapshot.
        binding_tamper = run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="raw-canonical-binding-tamper",
        )
        binding_source = joinpath(
            evidence_root,
            binding_tamper.record.source_model_artifact,
        )
        write(
            binding_source,
            m4_setpoint_model_json(M4SetPointModel(
                ["only"],
                [("only", "only")],
            )),
        )
        rewrite_json_and_seal!(binding_tamper.path, "evaluation.json") do payload
            payload["source_model_sha256"] = digest(binding_source)
        end
        binding_audit = audit_model_evaluation(
            evidence_root,
            "raw-canonical-binding-tamper";
            project_root=project_root,
        )
        @test binding_audit.ok
        @test binding_audit.semantic_replay == :failed
        @test any(
            contains("does not canonicalize to the model snapshot"),
            binding_audit.replay_errors,
        )

        # A structurally valid canonical model cannot be relabelled as an
        # execution error, even when evaluation.json and its seal agree.
        forged_error = run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="forged-error-outcome",
        )
        rewrite_json_and_seal!(forged_error.path, "evaluation.json") do payload
            payload["outcome"] = "error"
            payload["error_stage"] = "checker"
            payload["error_message"] = "forged checker error"
            payload["error_diagnostics"] = [Dict(
                "stage" => "checker",
                "message" => "forged checker error",
            )]
        end
        forged_error_audit = audit_model_evaluation(
            evidence_root,
            "forged-error-outcome";
            project_root=project_root,
        )
        @test forged_error_audit.ok
        @test forged_error_audit.semantic_replay == :failed
        @test any(
            contains("outcome does not match the canonical source model"),
            forged_error_audit.replay_errors,
        )

        draft_paths = Dict{String,String}()
        for id in (
            "draft-packet-tamper",
            "draft-seal-tamper",
            "draft-source-tamper",
        )
            run_m4_model_evaluation(
                project_root,
                reject_source;
                output_root=evidence_root,
                model_root=evidence_root,
                evaluation_id=id,
                claim_relation=:counterexample_candidate,
            )
            draft_paths[id] = write_counterexample_draft_packet(
                evidence_root,
                id;
                project_root=project_root,
            )
        end
        open(draft_paths["draft-packet-tamper"], "a") do io
            write(io, "\n")
        end
        @test !audit_counterexample_draft(
            evidence_root,
            "draft-packet-tamper";
            project_root=project_root,
        ).ok
        write(
            joinpath(dirname(draft_paths["draft-seal-tamper"]), "seal.sha256"),
            "invalid\n",
        )
        @test !audit_counterexample_draft(
            evidence_root,
            "draft-seal-tamper";
            project_root=project_root,
        ).ok
        source_tamper_evaluation = model_evaluation_path(
            evidence_root,
            "draft-source-tamper",
        )
        open(source_tamper_evaluation, "a") do io
            write(io, "\n")
        end
        source_tamper_audit = audit_counterexample_draft(
            evidence_root,
            "draft-source-tamper";
            project_root=project_root,
        )
        @test !source_tamper_audit.ok
        @test any(
            contains("source evaluation"),
            source_tamper_audit.errors,
        )

        draft_parent = joinpath(evidence_root, "logs", "counterexample-candidates")
        mkpath(joinpath(draft_parent, ".pending-test"))
        write(joinpath(draft_parent, "foreign.txt"), "foreign\n")
        draft_inventory = list_counterexample_drafts(
            evidence_root;
            project_root=project_root,
        )
        @test any(
            entry -> entry.evaluation_id == ".pending-test" &&
                entry.entry_kind == :pending && !entry.audit_ok,
            draft_inventory,
        )
        @test any(
            entry -> entry.evaluation_id == "foreign.txt" &&
                entry.entry_kind == :foreign && !entry.audit_ok,
            draft_inventory,
        )
        draft_inventory_audit = audit_counterexample_drafts(
            evidence_root;
            project_root=project_root,
        )
        @test !draft_inventory_audit.ok
        @test draft_inventory_audit.failed >= 5

        # Tampering is visible and cannot silently become a valid historical result.
        tampered_model = joinpath(
            evidence_root,
            duplicate.record.model_artifact,
        )
        open(tampered_model, "a") do io
            write(io, "\n")
        end
        tampered_audit = audit_model_evaluation(
            evidence_root,
            "one-state-pass-again";
            project_root=project_root,
        )
        @test !tampered_audit.ok
        @test any(contains("model snapshot hash mismatch"), tampered_audit.errors)

        write(
            joinpath(dirname(malformed.path), "seal.sha256"),
            "invalid\n",
        )
        broken_seal = audit_model_evaluation(
            evidence_root,
            "malformed-input";
            project_root=project_root,
        )
        @test !broken_seal.ok
        @test any(contains("evaluation seal validation failed"), broken_seal.errors)
        broken_entry = only(filter(
            entry -> entry.evaluation_id == "malformed-input",
            list_model_evaluations(evidence_root; project_root=project_root),
        ))
        @test !broken_entry.audit_ok
        @test !audit_model_evaluation(
            evidence_root,
            "../escape";
            project_root=project_root,
        ).ok
        @test_throws ArgumentError model_evaluation_path(evidence_root, "../escape")

        @test_throws ArgumentError ERIEC._model_evaluation_registry_binding(
            project_root,
            "VP-BDY-001",
            "wrong.contract",
            "check_m4_no_terminal_setpoint",
        )

        mktempdir() do outside
            escaped_target = write_m4_setpoint_model(
                joinpath(outside, "outside.json"),
                M4SetPointModel(["outside"], Tuple{String,String}[]),
            )
            escaped_link = joinpath(models, "escaped-link.json")
            symlink(escaped_target, escaped_link)
            @test_throws ArgumentError run_m4_model_evaluation(
                project_root,
                escaped_link;
                output_root=evidence_root,
                model_root=evidence_root,
                evaluation_id="must-not-exist",
            )
            @test !ispath(model_evaluation_path(evidence_root, "must-not-exist"))
        end

        mktempdir() do escaped_output
            output_root = joinpath(evidence_root, "escaped-output")
            mkpath(output_root)
            symlink(escaped_output, joinpath(output_root, "logs"))
            @test_throws ArgumentError run_m4_model_evaluation(
                project_root,
                duplicate_source;
                output_root=output_root,
                model_root=evidence_root,
                evaluation_id="escaped-output-write",
            )
            @test isempty(readdir(escaped_output))
        end

        mktempdir() do external_parent
            external_evaluation = joinpath(external_parent, "one-state-pass")
            cp(dirname(passed.path), external_evaluation)
            mktempdir() do second_evidence
                evaluations = joinpath(second_evidence, "logs", "model-evaluations")
                mkpath(evaluations)
                symlink(
                    external_evaluation,
                    joinpath(evaluations, "one-state-pass"),
                )
                escaped_audit = audit_model_evaluation(
                    second_evidence,
                    "one-state-pass";
                    project_root=project_root,
                )
                @test !escaped_audit.ok
                @test any(
                    contains("evaluation directory escapes the evidence root"),
                    escaped_audit.errors,
                )
            end
        end

        symlinked_evaluation = run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="external-evaluation-json-symlink",
        )
        mktempdir() do outside
            external_json = joinpath(outside, "evaluation.json")
            cp(symlinked_evaluation.path, external_json)
            rm(symlinked_evaluation.path)
            symlink(external_json, symlinked_evaluation.path)
            evaluation_symlink_audit = audit_model_evaluation(
                evidence_root,
                "external-evaluation-json-symlink";
                project_root=project_root,
            )
            @test !evaluation_symlink_audit.ok
            @test any(
                contains("evaluation.json must not be a symlink"),
                evaluation_symlink_audit.errors,
            )
        end

        symlinked_seal = run_m4_model_evaluation(
            project_root,
            duplicate_source;
            output_root=evidence_root,
            model_root=evidence_root,
            evaluation_id="external-seal-symlink",
        )
        seal_path = joinpath(dirname(symlinked_seal.path), "seal.sha256")
        mktempdir() do outside
            external_seal = joinpath(outside, "seal.sha256")
            cp(seal_path, external_seal)
            rm(seal_path)
            symlink(external_seal, seal_path)
            seal_symlink_audit = audit_model_evaluation(
                evidence_root,
                "external-seal-symlink";
                project_root=project_root,
            )
            @test !seal_symlink_audit.ok
            @test any(
                contains("seal.sha256 must not be a symlink"),
                seal_symlink_audit.errors,
            )
        end

        evaluation_parent = joinpath(evidence_root, "logs", "model-evaluations")
        mkpath(joinpath(evaluation_parent, ".pending-test"))
        write(joinpath(evaluation_parent, "foreign.txt"), "foreign\n")
        dangling_path = joinpath(evaluation_parent, "dangling-symlink")
        symlink(joinpath(evidence_root, "missing-target"), dangling_path)
        filtered_broken = list_model_evaluations(
            evidence_root;
            project_root=project_root,
            vp_id="VP-NOT-PRESENT",
            outcome=:pass,
        )
        @test any(
            entry -> entry.evaluation_id == "malformed-input" && !entry.audit_ok &&
                entry.filter_match === false,
            filtered_broken,
        )
        @test any(
            entry -> entry.evaluation_id == ".pending-test" &&
                entry.entry_kind == :pending && !entry.audit_ok,
            filtered_broken,
        )
        @test any(
            entry -> entry.evaluation_id == "foreign.txt" &&
                entry.entry_kind == :foreign && !entry.audit_ok,
            filtered_broken,
        )
        @test any(
            entry -> entry.evaluation_id == "dangling-symlink" &&
                entry.entry_kind == :foreign && !entry.audit_ok,
            filtered_broken,
        )
        inventory_audit = audit_model_evaluations(
            evidence_root;
            project_root=project_root,
        )
        @test !inventory_audit.ok
        @test inventory_audit.failed >= 8
        @test !inventory_audit.semantic_replay_ok

        mktempdir() do symlink_root
            mktempdir() do external_logs
                symlink(external_logs, joinpath(symlink_root, "logs"))
                @test !audit_model_evaluations(
                    symlink_root;
                    project_root=project_root,
                ).ok
                @test_throws ArgumentError list_model_evaluations(
                    symlink_root;
                    project_root=project_root,
                )
            end
        end
    end
    @test digest(claim_ledger) == claim_ledger_before
end
