using Test
using TOML
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

function audit_test_context(; kwargs...)
    fields = merge((question_id="q1", question="視点は一意か", definition_version="v1",
        definition="与えた候補集合の不変な選択", assumptions=(),
        observation="candidate action", subject="symmetric pair"), (; kwargs...))
    ModelAudit.AuditContext(; fields...)
end

function audit_test_toml(data)
    io = IOBuffer()
    TOML.print(io, data; sorted=true)
    String(take!(io))
end

@testset "model audit records" begin
    c = audit_test_context()
    claim(verdict; context=c, proposition="唯一の選択がある") = (; context, proposition, verdict)
    @test ModelAudit.compare_audit_claims(claim(:affirmed), claim(:denied)).classification == :conflict_requires_review
    changed = audit_test_context(definition_version="v2", definition="番号順に選ぶ", assumptions=("番号を使用",))
    comparison = ModelAudit.compare_audit_claims(claim(:affirmed), claim(:denied; context=changed))
    @test comparison.classification == :different_context
    @test Set(comparison.differences) == Set((:definition_version, :definition, :assumptions))
    @test !comparison.same_context && comparison.opposite
    @test ModelAudit.compare_audit_claims(claim(:affirmed), claim(:undetermined)).classification == :underdetermined
    @test ModelAudit.compare_audit_claims(claim(:affirmed), claim(:affirmed)).classification == :compatible
    @test ModelAudit.compare_audit_claims(claim(:affirmed), claim(:denied; proposition="経験がない")).classification == :different_proposition
    @test ModelAudit.compare_audit_claims(claim(:affirmed), claim(:denied;
        context=audit_test_context(subject="different pair"))).classification == :different_context
    @test ModelAudit.compare_audit_claims(claim(:affirmed), claim(:denied;
        context=audit_test_context(question="別の問い"))).classification == :different_question
    @test_throws ArgumentError ModelAudit.compare_audit_claims(claim(:affirmed), claim(:false))
    @test_throws ArgumentError audit_test_context(question=" ")
    @test_throws ArgumentError audit_test_context(assumptions=("A", "A"))
    @test audit_test_context(assumptions=("A", "B")).assumptions ==
          audit_test_context(assumptions=("B", "A")).assumptions

    assumptions = ["A"]
    frozen = audit_test_context(assumptions=assumptions)
    push!(assumptions, "B")
    @test frozen.assumptions == ("A",)

    h1 = ModelAudit.append_audit_event((), c, :open; reason="元の問いを記録")
    h2 = ModelAudit.append_audit_event(h1, c, :explained;
        reason="固定した問いについて説明を申告", evidence=("fixture:context-1",))
    @test length(h1) == 1 && h1[1].status == :open
    @test length(h2) == 2 && h2[1] === h1[1]
    summary = ModelAudit.audit_history_summary(h2)
    @test summary.unresolved_count == 0 && summary.counts["explained"] == 1
    @test summary.interpretation == :requires_review
    @test summary.phenomenal_claim == :not_certified
    @test !hasproperty(summary, :success)
    @test_throws ArgumentError ModelAudit.append_audit_event((), c, :explained;
        reason="問いの登録なし", evidence=("ref",))
    @test_throws ArgumentError ModelAudit.append_audit_event(h1, c, :explained; reason="証拠なし")
    @test_throws ArgumentError ModelAudit.append_audit_event(h1, c, :conditional; reason="前提なし", evidence=("ref",))
    @test_throws ArgumentError ModelAudit.append_audit_event(h1, audit_test_context(question="原文を変更"),
        :open; reason="同じIDで差替え")
    hc = ModelAudit.append_audit_event(h1, frozen, :conditional;
        reason="前提Aの下での解消", evidence=("premise:A",))
    @test ModelAudit.audit_history_summary(hc).counts["conditional"] == 1
    next_context = audit_test_context(question_id="q2", question="機能的な索引は一意か")
    h3 = ModelAudit.append_audit_event(h2, next_context, :open; reason="問いを分ける")
    h4 = ModelAudit.append_audit_event(h3, c, :reformulated; reason="所有者と機能を区別",
        evidence=("design:split",), successor="q2")
    @test ModelAudit.audit_history_summary(h4).counts["reformulated"] == 1
    @test ModelAudit.audit_history_summary(h4).unresolved_count == 1
    @test_throws ArgumentError ModelAudit.append_audit_event(h1, c, :reformulated;
        reason="未登録の後続", evidence=("ref",), successor="missing")

    receipt = ModelAudit.audit_receipt(h4)
    text = ModelAudit.audit_history_toml(h4)
    restored = ModelAudit.parse_audit_history(text; expected_receipt=receipt)
    @test ModelAudit.audit_history_toml(restored) == text
    @test ModelAudit.audit_receipt(restored) == receipt
    @test isempty(ModelAudit.parse_audit_history(ModelAudit.audit_history_toml(())))
    @test_throws ArgumentError ModelAudit.parse_audit_history(ModelAudit.audit_history_toml(h3); expected_receipt=receipt)
    @test length(ModelAudit.parse_audit_history(ModelAudit.audit_history_toml(h3))) == 3 # Without an anchor, a valid prefix is indistinguishable.
    data = TOML.parse(text)
    for mutation in (
        d -> (d["events"][1]["reason"] = "書換え"),
        d -> (d["events"][2]["previous"] = repeat("0", 64)),
        d -> (d["events"][2]["sequence"] = 4),
        d -> (d["events"][1]["status"] = "unrecognised"),
        d -> (d["schema_version"] = true),
        d -> (d["phenomenal_claim"] = "certified"),
        d -> (d["extra"] = "ignored field"),
        d -> (d["events"][1]["context"]["extra"] = "ignored field"),
    )
        bad = deepcopy(data)
        mutation(bad)
        @test_throws ArgumentError ModelAudit.parse_audit_history(audit_test_toml(bad))
    end

    mktempdir() do dir
        path = joinpath(dir, "history.toml")
        write(path, text)
        cli = joinpath(@__DIR__, "..", "bin", "eriec-model-audit.jl")
        root = dirname(@__DIR__)
        output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli check-history $path $(receipt.count) $(receipt.head)`, String)
        checked = TOML.parse(output)
        @test checked["valid_history"] && checked["trusted_receipt_checked"]
        @test checked["interpretation"] == "requires_review"
    end
end

@testset "DC witnesses preserve the other conditions" begin
    examples = ModelAudit.abstract_dc_models()
    @test length(examples) == 5
    for example in examples
        result = ModelAudit.check_dc_pattern(example.model, example.expected)
        @test result.valid && result.nondegenerate && result.matches
        @test result.actual == example.expected
    end
    bad = deepcopy(examples[1].model)
    foreach(empty!, values(bad.rho))
    result = ModelAudit.check_dc_pattern(bad, (true, true, false, true))
    @test result.actual == (false, true, false, true)
    @test !result.matches
    bad.pi[:m1] = Set([:outside_carrier])
    @test !ModelAudit.check_dc_pattern(bad, (false, true, false, true)).valid

    measured = ModelAudit.measured_dc_model()
    result = ModelAudit.check_dc_pattern(measured.model, (true, true, true, true))
    @test result.matches && measured.active_boundary
    @test measured.model.kappa == Set((:e, :c, :m))
    @test measured.model.epsilon == Set([:e])
    @test result.boundary == Set([:m]) && result.act == Set([:m])
    @test measured.prefix[1:3] == [
        (true, true, true, true, false, false),
        (true, true, true, false, true, true),
        (true, true, true, true, false, false)]
    @test measured.traces[4][2] == (false, true, true, false, true, false)
    @test !measured.traces[4][4][3]
    @test all(first(t) == last(measured.prefix) for t in values(measured.traces))
    @test ModelAudit.invariant_choices((:left, :right), [(2, 1)]) == ()
    @test ModelAudit.invariant_choices((:left, :right), [(1, 2)]) == (:left, :right)
    @test ModelAudit.invariant_choices((:a, :b, :fixed), [(2, 1, 3)]) == (:fixed,)
    @test_throws ArgumentError ModelAudit.invariant_choices((:left, :right), [(1, 1)])
    @test_throws ArgumentError ModelAudit.invariant_choices((:left, :left), [(1, 2)])
    report = ModelAudit.model_witness_report()
    @test report["all_expected_patterns_matched"] && !report["execution_certified"]
    @test report["measured_single_failure_rows"] == "not_established"
    @test report["phenomenal_claim"] == "not_certified"
    @test TOML.parse(audit_test_toml(report))["all_expected_patterns_matched"]
end
