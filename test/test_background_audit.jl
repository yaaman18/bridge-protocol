using Test
using TOML
isdefined(@__MODULE__, :BackgroundAudit) || include(joinpath(@__DIR__,"..","tools","BackgroundAudit.jl"))

@testset "adjunction is an explicit background, not a hidden DC field" begin
    examples = BackgroundAudit.relative_abstract_models()
    for example in examples
        bg = BackgroundAudit.check_adjunction_background(example.model)
        @test bg.holds && bg.counterexample === nothing && bg.checker_matched
        @test bg.checked_pairs == 1 << (length(example.model.M)+length(example.model.E))
        @test ModelAudit.check_dc_pattern(example.model,example.expected).matches
    end
    for example in ModelAudit.abstract_dc_models()
        bg = BackgroundAudit.check_adjunction_background(example.model)
        if !bg.holds
            ce = bg.counterexample
            @test ce.N ⊆ Set(example.model.M) && ce.X ⊆ Set(example.model.E)
            @test ce.lhs != ce.rhs
            @test ce.lhs == (ERIEC.alpha_star(m -> example.model.alpha[m],ce.N) ⊆ ce.X)
            @test ce.rhs == (ce.N ⊆ ERIEC.sigma_star(e -> example.model.sigma[e],ce.X))
        end
    end
    old = ModelAudit.measured_dc_model()
    @test BackgroundAudit.check_adjunction_background(old.model).holds
    @test ModelAudit.check_dc_pattern(old.model,(true,true,true,true)).matches
    corpus = ModelAudit.measured_witness_corpus()
    for row in corpus["witnesses"]
        measured = ModelAudit.measure_circuit(ModelAudit.parse_audit_circuit(row["circuit"]))
        bg = BackgroundAudit.check_adjunction_background(measured.model)
        @test bg.checker_matched
        if !bg.holds
            @test bg.counterexample.lhs != bg.counterexample.rhs
        end
    end
    report = BackgroundAudit.background_audit_report()
    @test length(report["models"]) == 11 && !report["dc_definition_changed"]
    @test report["full_M1_M4"] == "not_established" && !report["execution_certified"]
    root = dirname(@__DIR__)
    cli = joinpath(root,"bin","eriec-background-audit.jl")
    output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli examples`,String)
    @test TOML.parse(output)["phenomenal_claim"] == "not_certified"
end
