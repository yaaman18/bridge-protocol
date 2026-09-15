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
    @test summary.context_shift_count == 0 && isempty(summary.context_shifts)
    # Status changes stay legal, but cannot hide a change of context.
    for (field, value) in ((:definition_version, "v2"), (:definition, "different definition"),
                          (:assumptions, ("A",)), (:observation, "different observation"),
                          (:subject, "different subject"))
        shifted = audit_test_context(; (field => value,)...)
        shifted_history = ModelAudit.append_audit_event(h1, shifted, :explained;
            reason="別文脈での申告", evidence=("fixture:shift",))
        # Recompute from serialized events, without a caller-supplied diagnostic.
        shifted_summary = ModelAudit.audit_history_summary(ModelAudit.parse_audit_history(
            ModelAudit.audit_history_toml(shifted_history)))
        @test shifted_summary.unresolved_count == 0
        @test shifted_summary.context_shift_count == 1
        change = only(shifted_summary.context_shifts)
        @test change["question_id"] == "q1"
        @test (change["from_sequence"], change["to_sequence"]) == (1, 2)
        @test change["changed_fields"] == [String(field)]
        @test change["before"] == ModelAudit._context_dict(c)
        @test change["after"] == ModelAudit._context_dict(shifted)
        returned = ModelAudit.append_audit_event(shifted_history, c, :open; reason="元の文脈へ戻る")
        @test ModelAudit.audit_history_summary(returned).context_shift_count == 2
    end
    @test_throws ArgumentError ModelAudit.append_audit_event((), c, :explained;
        reason="問いの登録なし", evidence=("ref",))
    @test_throws ArgumentError ModelAudit.append_audit_event(h1, c, :explained; reason="証拠なし")
    @test_throws ArgumentError ModelAudit.append_audit_event(h1, c, :conditional; reason="前提なし", evidence=("ref",))
    @test_throws ArgumentError ModelAudit.append_audit_event(h1, audit_test_context(question="原文を変更"),
        :open; reason="同じIDで差替え")
    hc = ModelAudit.append_audit_event(h1, frozen, :conditional;
        reason="前提Aの下での解消", evidence=("premise:A",))
    @test ModelAudit.audit_history_summary(hc).counts["conditional"] == 1
    @test only(ModelAudit.audit_history_summary(hc).context_shifts)["changed_fields"] == ["assumptions"]
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
        @test checked["context_shift_count"] == 0 && isempty(checked["context_shifts"])
        write(path, ModelAudit.audit_history_toml(hc))
        shifted_output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli check-history $path`, String)
        shifted_checked = TOML.parse(shifted_output)
        @test shifted_checked["context_shift_count"] == 1
        @test only(shifted_checked["context_shifts"])["after"]["assumptions"] == ["A"]
    end
end

@testset "DC predicates match direct quantifiers on all tiny encodings" begin
    # Enumerate all alpha/sigma/pi/rho relations and supports on this fixed carrier.
    # No ERIEC operators or checker results are used to obtain the reference values.
    C = (:e, :m, :c)
    observed_patterns = Set{NTuple{4,Bool}}()
    for bits in 0:4095
        bit(i) = !iszero(bits & (1 << i))
        model = (M=(:m,), E=(:e,), C=C,
            alpha=Dict(:m => Set{Symbol}(bit(0) ? (:e,) : ())),
            sigma=Dict(:e => Set{Symbol}(bit(1) ? (:m,) : ())),
            pi=Dict(:m => Set(C[i] for i in 1:3 if bit(i+1))),
            rho=Dict(C[i] => Set{Symbol}(bit(i+4) ? (:m,) : ()) for i in 1:3),
            kappa=Set(C[i] for i in 1:3 if bit(i+7)),
            epsilon=Set{Symbol}(bit(11) ? (:e,) : ()),
            neighbors=Dict(c => Set(d for d in C if d != c) for c in C))
        K, I = model.kappa, model.epsilon
        produced(c) = any(c in model.pi[m] && any(m in model.rho[d] for d in K) for m in model.M)
        returned(e) = any(e in model.alpha[m] && any(m in model.sigma[d] for d in I) for m in model.M)
        active(m) = any(m in model.rho[d] for d in K) && any(m in model.sigma[e] for e in I)
        reference = (all(produced, K), all(returned, I), any(active, model.M),
            any(any(d ∉ K for d in model.neighbors[c]) for c in K))
        result = ModelAudit.check_dc_pattern(model, reference)
        @test result.valid && result.actual == reference
        @test result.act == Set(m for m in model.M if active(m))
        @test result.matches == (!isempty(K) && K != Set(C) && !isempty(I))
        push!(observed_patterns, reference)
    end
    # Every component was observed both true and false; this is not a general independence claim.
    @test all(Set(p[i] for p in observed_patterns) == Set((false, true)) for i in 1:4)
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
    invalid = ModelAudit.check_dc_pattern(bad, (false, true, false, true))
    @test !invalid.valid
    @test invalid.actual == () # Encoding rejection, not checker disagreement.

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
