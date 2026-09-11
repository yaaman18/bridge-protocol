using Test
using TOML
isdefined(@__MODULE__, :ClosureAudit) || include(joinpath(@__DIR__,"..","tools","ClosureAudit.jl"))

@testset "observed support is not silently replaced by greatest closure" begin
    for witness in BackgroundAudit.adjoint_measured_witnesses()
        measured = ModelAudit.measure_circuit(witness.circuit)
        before = deepcopy(measured.model)
        result = ClosureAudit.check_observed_closure(measured.model)
        @test measured.model == before && !result.write_back
        @test result.finite_fixedpoint && result.postfixed_covered
        @test result.hSelf == measured.result.actual[1]
        @test result.checked_carrier_subsets == 1 << length(measured.model.C)
        @test result.iterations <= length(measured.model.C)+1
        if witness.name == "without_hSelf"
            @test !result.kappa_subset_nu && !isempty(result.kappa_outside_nu)
        elseif witness.name == "without_hAct"
            @test result.kappa_subset_nu && !result.kappa_equals_nu
            @test result.kappa == Set([:u3])
            @test result.nu_phi == Set([:u1,:u3,:u6,:u7,:u8,:u10])
        end
    end
    old = ModelAudit.measured_dc_model().model
    @test ClosureAudit.check_observed_closure(old).kappa_equals_nu
    bad = deepcopy(old)
    bad.pi[:m] = Set([:outside])
    @test_throws ArgumentError ClosureAudit.check_observed_closure(bad)
    report = ClosureAudit.closure_audit_report()
    @test length(report["models"]) == 7
    @test !report["write_back"] && !report["M1_equivalence_claim"]
    expansion = ModelAudit.measure_circuit(ClosureAudit._support_expansion_witness())
    @test expansion.result.actual == (true,true,true,true)
    @test BackgroundAudit.check_adjunction_background(expansion.model).holds
    result = ClosureAudit.check_observed_closure(expansion.model)
    @test result.hSelf && result.kappa_subset_nu && !result.kappa_equals_nu
    @test result.kappa == Set([:u3,:u6]) && result.phi_kappa != result.kappa
    root = dirname(@__DIR__)
    cli = joinpath(root,"bin","eriec-closure-audit.jl")
    output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli examples`,String)
    @test !TOML.parse(output)["execution_certified"]
end
