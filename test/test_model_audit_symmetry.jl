using Test
using TOML
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

function symmetric_pair_fixture(; initial=(true,true,true,true), thresholds=(1,1,1,1))
    ModelAudit.AuditCircuit(units=(:e1,:m1,:e2,:m2), motors=(:m1,:m2), inputs=(:e1,:e2),
        edges=((1,2,1),(2,1,1),(3,4,1),(4,3,1)), thresholds=thresholds,
        initial=initial, P=6,H=6,L=4,R=4)
end

@testset "physical symmetries and candidate closure" begin
    c = symmetric_pair_fixture()
    supports = ((:e1,:m1), (:e2,:m2))
    autos = ModelAudit.circuit_automorphisms(c)
    @test Set(autos) == Set(((1,2,3,4), (3,4,1,2)))
    audit = ModelAudit.audit_candidate_supports(c, supports)
    @test audit.classification == :obstructed_by_symmetry && isempty(audit.fixed)
    @test audit.orbits == ((3,12),(3,12))
    @test audit.candidate_class_externally_supplied && !audit.intrinsic_decomposition_certified
    @test_throws ArgumentError ModelAudit.audit_candidate_supports(c, ((:e1,:m1),))
    @test_throws ArgumentError ModelAudit.audit_candidate_supports(c, ((:e1,:m1), (:m1,:e1)))
    @test_throws ArgumentError ModelAudit.audit_candidate_supports(c, ((:outside,),))
    @test_throws ArgumentError ModelAudit.audit_candidate_supports(c, (c.units,))
    @test_throws ArgumentError ModelAudit.audit_candidate_supports(c, ())
    @test_throws ArgumentError ModelAudit.audit_candidate_supports(c, ((),))
    # A unique invariant support is only compatibility with the specified symmetries.
    one = ModelAudit.audit_candidate_supports(c, ((:e1,:e2),))
    @test one.classification == :one_symmetry_compatible_candidate
    @test !one.intrinsic_decomposition_certified
    broken = symmetric_pair_fixture(initial=(true,true,false,false))
    @test length(ModelAudit.circuit_automorphisms(broken)) == 1
    @test length(ModelAudit.circuit_automorphisms(broken; include_initial=false)) == 2
    broken_audit = ModelAudit.audit_candidate_supports(broken, supports)
    @test broken_audit.classification == :multiple_symmetry_compatible_candidates
    @test length(ModelAudit.circuit_automorphisms(symmetric_pair_fixture(thresholds=(1,1,2,1)))) == 1
    for permutation in autos, bits in 0:15, source_mask in 0:15
        state = ntuple(i -> !iszero(bits & (1 << (i-1))), 4)
        move(x) = ntuple(i -> x[findfirst(==(i), permutation)], 4)
        moved_mask = ModelAudit._permuted_support(source_mask, permutation)
        @test move(ModelAudit._audit_step(state, c.edges, c.thresholds, source_mask)) ==
            ModelAudit._audit_step(move(state), c.edges, c.thresholds, moved_mask)
    end
    # Initial-state asymmetry affects whole traces, not equivariance of the update rule.
    report = ModelAudit.symmetry_audit_report(broken_audit)
    @test report["context"] == "dynamics_roles_and_initial_state"
    @test report["candidate_class_closed"] && !report["execution_certified"]
    dynamics = ModelAudit.symmetry_audit_report(ModelAudit.audit_candidate_supports(broken, supports; include_initial=false))
    @test dynamics["context"] == "dynamics_and_roles" && dynamics["classification"] == "obstructed_by_symmetry"
    mktempdir() do dir
        circuit_path, support_path = joinpath(dir,"circuit.toml"), joinpath(dir,"supports.toml")
        open(io -> TOML.print(io, ModelAudit.circuit_dict(c); sorted=true), circuit_path, "w")
        open(io -> TOML.print(io, Dict("supports" => [String.(collect(s)) for s in supports], "include_initial" => true); sorted=true), support_path, "w")
        root = dirname(@__DIR__)
        cli = joinpath(root,"bin","eriec-model-audit.jl")
        output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli symmetry $circuit_path $support_path`, String)
        parsed = TOML.parse(output)
        @test parsed["classification"] == "obstructed_by_symmetry"
        @test parsed["automorphism_count"] == 2 && parsed["phenomenal_claim"] == "not_certified"
    end
end
