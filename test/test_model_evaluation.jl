using JSON3
using SHA
using Test
using ERIEC

digest(path) = bytes2hex(SHA.sha256(read(path)))

@testset "M4 model schema and canonical fingerprint input" begin
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
    @test_throws ArgumentError M4SetPointModel(["same", "same"], Tuple{String,String}[])

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
        @test aggregate_payload.checked == 3

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
        @test audit_model_evaluation(
            evidence_root,
            "one-state-pass";
            project_root=project_root,
        ).ok

        # The source may disappear; the evaluation remains reconstructible from snapshots.
        rm(pass_source)
        @test audit_model_evaluation(
            evidence_root,
            "one-state-pass";
            project_root=project_root,
        ).ok

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
        @test audit_model_evaluation(
            evidence_root,
            "empty-input";
            project_root=project_root,
        ).ok

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

        control_error = ERIEC._run_model_evaluation(
            project_root;
            output_root=evidence_root,
            evaluation_id="control-character-error",
            raw_model_bytes=UInt8[0x01],
            prepare_model=_ -> error("parse\tfailure\rcontrol"),
            vp_id="VP-BDY-001",
            contract_id="body.no_terminal_setpoint",
            checker_id="check_m4_no_terminal_setpoint",
            failed_predicates_on_reject=["ERIEC.Body.NoTerminalSetPoint"],
            adapter_id="m4-setpoint-model-v1",
            adapter_source="src/m4_model_evaluation.jl",
        )
        @test control_error.record.outcome == :error
        evaluation_text = read(control_error.path, String)
        @test !occursin('\t', evaluation_text)
        @test !occursin('\r', evaluation_text)
        @test read_model_evaluation(control_error.path).outcome == :error
        unknown_evaluation_field = replace(
            strip(evaluation_text),
            r"}$" => ",\"unknown_field\":true}",
        )
        @test_throws ArgumentError parse_model_evaluation_json(unknown_evaluation_field)

        checker_dispatch_error = ERIEC._run_model_evaluation(
            project_root;
            output_root=evidence_root,
            evaluation_id="checker-dispatch-error",
            raw_model_bytes=read(duplicate_source),
            prepare_model=bytes -> (
                value=1,
                canonical_bytes=Vector{UInt8}(codeunits(m4_setpoint_model_json(
                    parse_m4_setpoint_model_json(String(copy(bytes))),
                ))),
                fingerprint_algorithm=M4_SETPOINT_FINGERPRINT_ALGORITHM,
            ),
            vp_id="VP-BDY-001",
            contract_id="body.no_terminal_setpoint",
            checker_id="check_m4_no_terminal_setpoint",
            failed_predicates_on_reject=["ERIEC.Body.NoTerminalSetPoint"],
            adapter_id="m4-setpoint-model-v1",
            adapter_source="src/m4_model_evaluation.jl",
        )
        @test checker_dispatch_error.record.outcome == :error
        @test occursin("MethodError", checker_dispatch_error.record.error_message)

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
        @test aggregate.checked == 10
        duplicate_group = only(filter(
            group -> group.model_fingerprint == passed.record.model_fingerprint,
            aggregate.duplicate_fingerprints,
        ))
        @test Set(duplicate_group.evaluation_ids) ==
            Set([
                "one-state-pass",
                "one-state-pass-again",
                "checker-dispatch-error",
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

        # Even the private persistence primitive cannot smuggle a reject value
        # under a pass model fingerprint: adapter audit recomputes the outcome.
        pass_model = parse_m4_setpoint_model_json(read(duplicate_source, String))
        reject_diagram = m4_setpoint_diagram(
            M4SetPointModel(["only"], [("only", "only")]),
        )
        mismatched = ERIEC._run_model_evaluation(
            project_root;
            output_root=evidence_root,
            evaluation_id="mismatched-value-and-model",
            raw_model_bytes=read(duplicate_source),
            prepare_model=_ -> (
                value=reject_diagram,
                canonical_bytes=Vector{UInt8}(codeunits(m4_setpoint_model_json(pass_model))),
                fingerprint_algorithm=M4_SETPOINT_FINGERPRINT_ALGORITHM,
            ),
            vp_id="VP-BDY-001",
            contract_id="body.no_terminal_setpoint",
            checker_id="check_m4_no_terminal_setpoint",
            failed_predicates_on_reject=["ERIEC.Body.NoTerminalSetPoint"],
            adapter_id="m4-setpoint-model-v1",
            adapter_source="src/m4_model_evaluation.jl",
            claim_relation=:counterexample_candidate,
        )
        @test mismatched.record.outcome == :reject
        mismatched_audit = audit_model_evaluation(
            evidence_root,
            "mismatched-value-and-model";
            project_root=project_root,
        )
        @test !mismatched_audit.ok
        @test any(
            contains("M4 outcome does not match the canonical model"),
            mismatched_audit.errors,
        )
        @test_throws ArgumentError write_counterexample_draft_packet(
            evidence_root,
            "mismatched-value-and-model";
            project_root=project_root,
        )

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
