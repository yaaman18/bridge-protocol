using TOML
using Test
include(joinpath(@__DIR__,"..","..","..","tools","ClosureAudit.jl"))

@testset "a greatest support does not select one symmetric component" begin
    c = ModelAudit.AuditCircuit(units=(:u1,:u2,:u3,:u4,:u5,:u6),inputs=(:u1,:u2),motors=(:u5,:u6),
        edges=((1,5,1),(5,1,1),(2,6,1),(6,2,1),(5,3,1),(6,3,-1),(6,4,1),(5,4,-1)),
        thresholds=(1,1,1,1,1,1),initial=(true,true,false,false,true,true),P=3,H=6,L=4,R=4)
    measured = ModelAudit.measure_circuit(c)
    closure = ClosureAudit.check_observed_closure(measured.model)
    @test measured.result.actual == (true,true,true,true) && measured.active_boundary
    @test BackgroundAudit.check_adjunction_background(measured.model).holds
    @test closure.kappa_equals_nu
    left,right = Set([:u1,:u5]),Set([:u2,:u6])
    phi(X) = ERIEC.Phi(m -> measured.model.pi[m],u -> measured.model.rho[u],X)
    @test phi(left) == left && phi(right) == right
    @test isempty(left ∩ right) && union(left,right) == closure.nu_phi
    components = ModelAudit.audit_candidate_supports(c,(Tuple(left),Tuple(right)))
    united = ModelAudit.audit_candidate_supports(c,(Tuple(closure.nu_phi),))
    @test length(components.automorphisms) == 2 && isempty(components.fixed)
    @test components.classification == :obstructed_by_symmetry
    @test united.classification == :one_symmetry_compatible_candidate
    @test !united.intrinsic_decomposition_certified
    row = Dict("schema_version"=>1,"phenomenal_claim"=>"not_certified","execution_certified"=>false,
        "measurement"=>ModelAudit.circuit_measurement_report(measured),
        "nu_phi"=>ModelAudit._audit_names(closure.nu_phi),
        "component_candidates"=>ModelAudit.symmetry_audit_report(components),
        "union_candidate"=>ModelAudit.symmetry_audit_report(united),
        "claim"=>"greatest_fixed_support_is_not_a_choice_of_one_component")
    open(io -> TOML.print(io,row;sorted=true),joinpath(@__DIR__,"symmetric-union-witness.toml"),"w")
end
