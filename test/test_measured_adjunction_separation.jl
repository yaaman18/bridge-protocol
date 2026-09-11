using Test
using TOML
isdefined(@__MODULE__, :BackgroundAudit) || include(joinpath(@__DIR__,"..","tools","BackgroundAudit.jl"))

@testset "measured DC separation with adjunction in a common P3 context" begin
    examples = BackgroundAudit.adjoint_measured_witnesses()
    @test length(examples) == 5
    for example in examples
        c = example.circuit
        @test (c.P,c.H,c.L,c.R) == (3,6,4,4)
        @test length(c.motors) == 2 && length(c.inputs) == 2
        measured = ModelAudit.measure_circuit(c)
        background = BackgroundAudit.check_adjunction_background(measured.model)
        @test background.holds && background.checker_matched
        @test measured.result.actual == example.expected
        @test measured.result.valid && measured.result.nondegenerate
        @test !example.expected[4] || measured.active_boundary
        @test measured.all_interventions && length(measured.traces) == 1 << length(c.units)
        @test ModelAudit.verify_measurement_report(ModelAudit.circuit_measurement_report(measured))
        if example.name == "without_hSMC"
            @test measured.model.kappa == Set([:u1,:u6])
            @test measured.model.epsilon == Set([:u1,:u2])
            @test measured.model.alpha == Dict(:u6=>Set([:u1]),:u7=>Set([:u1]))
            @test isempty(measured.model.sigma[:u2])
        elseif example.name == "without_hAct"
            @test measured.model.kappa == Set([:u3])
            @test measured.model.epsilon == Set([:u2])
            @test measured.model.rho[:u3] == Set([:u10])
            @test measured.model.sigma[:u2] == Set([:u11])
        end
    end
    for n in (12,13)
        fields = (units=ntuple(i -> Symbol("u$i"),n),motors=(:u2,),inputs=(:u1,),edges=(),
            thresholds=ntuple(_->1,n),initial=ntuple(_->false,n),P=0,H=1,L=1,R=1)
        if n == 12
            @test length(ModelAudit.AuditCircuit(;fields...).units) == 12
        else
            @test_throws ArgumentError ModelAudit.AuditCircuit(;fields...)
            @test_throws ArgumentError ModelAudit.minimal_loss_masks(Dict(),:u1,n)
        end
    end
    report = BackgroundAudit.adjoint_measured_witness_report()
    @test report["all_relative_patterns_matched"] && report["full_M1_M4"] == "not_established"
    @test !report["execution_certified"] && report["phenomenal_claim"] == "not_certified"
end
