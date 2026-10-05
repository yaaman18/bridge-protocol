using Test
using TOML
using ERIEC
isdefined(@__MODULE__, :DC2Audit) || include(joinpath(@__DIR__, "..", "tools", "DC2Audit.jl"))

# DC2 audit (logs/reviews/finite-model-audit-progress-20260930.md, recommendations 1–4).
# DC2 is the unratified experiment of formal-experiments/M1Refinement.lean. Since 2026-09-30 its
# hUnit is MutualPair (specs/packets/DC2-HUNIT-N3.md); the former IrredUnit ∧ NonSingleton is
# still checked as hUnit_v1.

# Reference written directly from the Lean statements with ∀/∃ over elements. It uses neither
# ModelAudit's DC2 helpers nor ERIEC's star operators. `distinct = false` drops MutualPair's c ≠ d;
# the mutation test below uses it to show that the comparison can fail.
function direct_dc2(m; distinct=true)
    C, M = collect(m.C), collect(m.M)
    K, eps = collect(m.kappa), collect(m.epsilon)
    # Phi Y ∋ c  ⟺  ∃ a, c ∈ pi a ∧ ∃ y ∈ Y, a ∈ rho y
    in_phi(rho, Y, c) = any(a -> c in m.pi[a] && any(y -> a in rho[y], Y), M)
    # Psi Y ∋ c  ⟺  ∃ a ∈ rho c, ∃ y ∈ Y, y ∈ pi a
    in_psi(rho, Y, c) = any(a -> a in rho[c] && any(y -> y in m.pi[a], Y), M)
    post(rho, Y) = all(c -> in_phi(rho, Y, c) && in_psi(rho, Y, c), Y)
    subsets(xs) = isempty(xs) ? [eltype(xs)[]] :
        (rest = subsets(xs[2:end]); vcat(rest, [[xs[1]; r] for r in rest]))
    parts = filter(!isempty, subsets(K))
    # Act = rho*(K) ∩ sigma*(eps)
    act = [a for a in M if any(k -> a in m.rho[k], K) && any(e -> a in m.sigma[e], eps)]
    rhoNH = Dict(c => [a for a in m.rho[c] if !(a in act)] for c in C)
    irreducible(U) = post(m.rho, U) &&
        !any(W -> length(W) < length(U) && all(w -> w in U, W) && post(m.rho, W), parts)
    (hSelf2 = post(m.rho, K),
     hSMC = all(e -> any(a -> e in m.alpha[a] && any(f -> a in m.sigma[f], eps), M), eps),
     hHingeNeeded = !any(V -> post(rhoNH, V), parts),
     # MutualPair: ∃ c ∈ K, ∃ d ∈ K, c ≠ d ∧ c ∈ Phi {d} ∧ d ∈ Phi {c}
     hUnit = any(c != d || !distinct ? in_phi(m.rho, [d], c) && in_phi(m.rho, [c], d) : false
                 for c in K, d in K),
     hUnit_v1 = any(U -> length(U) >= 2 && irreducible(U), parts),
     act = Set(act),
     beta = Set(c for c in K if any(a -> a in act && c in m.pi[a], M)))
end

dc_state(m, boundary) = ERIEC.ERIEState{Symbol,Symbol,Symbol,Nothing}(
    a -> copy(m.alpha[a]), e -> copy(m.sigma[e]), a -> copy(m.pi[a]), c -> copy(m.rho[c]),
    _ -> Set{Symbol}(m.kappa), _ -> Set{Symbol}(m.epsilon), Set{Symbol}(boundary), nothing)

const DC2_REPORT_LOG = joinpath(@__DIR__, "..", "logs", "gates", "DC2-AUDIT-20260930", "dc2-audit-report.toml")

@testset "DC2 checker agrees with the Lean reference models" begin
    rows = DC2Audit.lean_agreement()
    @test length(rows) == 16
    @test all(r -> r["agrees"], rows)
    for ref in ModelAudit.lean_reference_m1r()
        d, r = ModelAudit.check_dc2(ref.model), direct_dc2(ref.model)
        @test (d.hSelf2, d.hSMC, d.hHingeNeeded, d.hUnit, d.hUnit_v1) ==
              (r.hSelf2, r.hSMC, r.hHingeNeeded, r.hUnit, r.hUnit_v1)
        @test d.phenomenal_claim == :not_certified
    end
end

@testset "DC2 checker equals the direct quantifiers on every C3 M2 E1 encoding" begin
    counts = Dict(p.name => 0 for p in ModelAudit.DC2_PATTERNS)
    mismatches = 0
    dc2_true = 0
    mirror_failures = 0
    seen = Dict(k => Set{Bool}() for k in (:hSelf2, :hSMC, :hHingeNeeded, :hUnit, :hUnit_v1))
    for bits in 0:((1 << ModelAudit.DC2_CARRIER_BITS) - 1)
        m = ModelAudit.dc2_carrier_model(bits)
        d = ModelAudit.check_dc2(m)
        r = direct_dc2(m)
        same = d.valid && (d.hSelf2, d.hSMC, d.hHingeNeeded, d.hUnit) ==
               (r.hSelf2, r.hSMC, r.hHingeNeeded, r.hUnit) && d.act == r.act && d.beta == r.beta &&
               d.hUnit_v1 == r.hUnit_v1
        same || (mismatches += 1)
        for k in keys(seen)
            push!(seen[k], getproperty(r, k))
        end
        name = ModelAudit._dc2_pattern_name(r)
        name === nothing || (counts[name] += 1)
        if r.hSelf2 && r.hSMC && r.hHingeNeeded && r.hUnit
            dc2_true += 1
            # DC2.toDC: with boundary := beta, every DC2 encoding is a DC encoding.
            ok = !isempty(r.beta) && ERIEC.is_DC(ERIEC.check_DC(dc_state(m, r.beta)))
            ok || (mirror_failures += 1)
        end
    end
    @test mismatches == 0
    @test all(v -> v == Set([true, false]), values(seen))   # no component is constant here
    @test dc2_true == 12105
    @test mirror_failures == 0
    @test counts == Dict("all_four" => 12105, "without_hSelf2" => 4587, "without_hSMC" => 6187,
                         "without_hHingeNeeded" => 55952, "without_hUnit" => 121712)
end

@testset "the direct comparison can fail (mutation: c ≠ d dropped)" begin
    # Without c ≠ d a self-producing constituent counts. Some encoding must then disagree.
    found = false
    for bits in 0:((1 << ModelAudit.DC2_CARRIER_BITS) - 1)
        m = ModelAudit.dc2_carrier_model(bits)
        if ModelAudit.check_dc2(m).hUnit != direct_dc2(m; distinct=false).hUnit
            found = true
            break
        end
    end
    @test found
end

@testset "DC2 enters the catalog, the implication matrix and the separation table" begin
    corpus = ModelAudit.dc2_witness_corpus()     # replays every frozen witness
    @test length(corpus["abstract"]) == 9 && length(corpus["measured"]) == 9
    catalog = CountermodelAudit.finite_model_catalog()
    @test catalog["model_count"] == 34
    for key in ("dc2", "hSelf2", "hHingeNeeded", "hUnit", "beta_nonempty")
        @test Symbol(key) in CountermodelAudit.QUERY_PREDICATES
        @test all(r -> haskey(r["observations"], key), catalog["models"])
        @test Set(r["observations"][key] for r in catalog["models"]) == Set([true, false])
    end
    # A DC2 row never claims all_dc true without all four observed components true.
    @test all(catalog["models"]) do r
        o = r["observations"]
        !get(o, "all_dc", false) || all(get(o, k, false) for k in ("hSelf", "hSMC", "hAct", "hBound"))
    end

    matrix = ImplicationMatrixAudit.implication_matrix_report(catalog)
    cell(ctx, goal) = ImplicationMatrixAudit.find_implication(matrix, ctx, :dc2, goal)
    # Recommendation 3: DC2 ⇒ hSelf, hSMC, hAct, beta nonempty has no finite counterexample in any
    # context (consistent with the Lean theorem DC2.toDC), and it is instantiated in every context.
    for block in matrix["contexts"], goal in (:hSelf, :hSMC, :hAct, :beta_nonempty)
        c = cell(block["context"], goal)
        @test c["status"] == "no_counterexample_in_finite_catalog"
        @test c["premise_model_count"] >= 1 && !c["implication_proved"]
    end
    # DC2 ⇏ the graph-boundary hBound (analysis plan v1 error 1): finite counterexamples, abstract
    # and measured.
    @test cell("lean_reference_M1R", :hBound)["countermodels"] == ["m1r-M1", "m1r-M5"]
    @test cell("abstract_carrier_C3_M2_E1", :hBound)["countermodels"] == ["dc2-c3-dc2-kappa-all"]
    @test cell("two_inputs_two_motors_P3_H6_L4_R4", :hBound)["countermodels"] == ["p3-adjoint-without_hBound"]
    @test cell("one_input_two_motors_P6_H6_L4_R4", :hBound)["countermodels"] == ["p6-dc-only-without_hBound"]
    @test cell("abstract_carrier_C3_M2_E1", :all_dc)["status"] == "counterexample_found"

    # Recommendation 4: all conditions and every single drop have a nondegenerate witness, in the
    # C4 carrier and in the measured one-input two-motor context.
    table = DC2Audit.separation_table(catalog)
    for ctx in ("abstract_carrier_C4_M2_E1", "one_input_two_motors_P6_H6_L4_R4")
        rows = [row for row in table if row["context"] == ctx]
        @test length(rows) == 5 && all(row -> !isempty(row["nondegenerate_witnesses"]), rows)
    end
    lean = Dict(row["pattern"] => row["witnesses"] for row in table if row["context"] == "lean_reference_M1R")
    @test lean["all_four"] == ["m1r-M1", "m1r-M5"]
    @test lean["without_hSelf2"] == ["m1r-M2"]
    @test lean["without_hHingeNeeded"] == ["m1r-M3", "m1r-M4"]
end

@testset "the stored DC2 gate report matches a recomputation" begin
    stored = TOML.parsefile(DC2_REPORT_LOG)
    fresh = DC2Audit.dc2_audit_report(measured_search=false)
    for key in ("lean_agreement", "carrier_C3_M2_E1", "carrier_C4_M2_E1", "separation", "dc2_implications")
        @test ModelAudit._audit_digest(Dict("x" => stored[key])) == ModelAudit._audit_digest(Dict("x" => fresh[key]))
    end
    # Under the former hUnit no measured circuit had a non-singleton irreducible unit, because every
    # post-fixed core contains a constituent that is post-fixed on its own (DC2-HUNIT-N3 §2).
    # Under MutualPair both measured domains realize DC2 on nondegenerate circuits.
    for s in stored["measured_search"]
        @test s["nonempty_core_postfixed2"] == s["of_which_contain_singleton_postfixed2"]
        @test s["nondegenerate_counts"]["all_four"] > 0 && s["nondegenerate_counts"]["without_hUnit"] > 0
    end
    @test stored["phenomenal_claim"] == "not_certified" && !stored["implication_proved"]
end
