using TOML
using Test
include(joinpath(@__DIR__,"..","..","..","tools","BackgroundAudit.jl"))

function construct_circuit(name)
    core = [(1,5,1),(5,1,1),(2,6,1),(6,2,1)]
    extra,initial = if name == "all_four"
        ([(5,3,1),(6,3,-1)], (true,true,false,false,true,true))
    elseif name == "without_hSelf"
        ([(5,3,1),(6,3,1),(5,4,1),(6,4,-1)], (true,true,true,false,true,true))
    else
        ([(3,4,1),(4,3,1)], (true,true,true,false,true,true))
    end
    ModelAudit.AuditCircuit(units=(:u1,:u2,:u3,:u4,:u5,:u6),motors=(:u5,:u6),inputs=(:u1,:u2),
        edges=vcat(core,extra),thresholds=(1,1,1,1,1,1),initial=initial,P=6,H=6,L=4,R=4)
end

rows = Dict{String,Any}[]
@testset "explicit two-input M2 witnesses" begin
    for (name,expected) in (("all_four",(true,true,true,true)),
                            ("without_hSelf",(false,true,true,true)),
                            ("without_hBound",(true,true,true,false)))
        c = construct_circuit(name)
        measured = ModelAudit.measure_circuit(c)
        bg = BackgroundAudit.check_adjunction_background(measured.model)
        @test bg.holds && bg.checker_matched
        @test measured.result.actual == expected && measured.result.valid && measured.result.nondegenerate
        @test !expected[4] || measured.active_boundary
        @test measured.model.epsilon == Set((:u1,:u2))
        @test measured.all_interventions && length(measured.traces) == 64
        @test measured.model.alpha == Dict(:u5=>Set([:u1]),:u6=>Set([:u2]))
        @test measured.model.sigma == Dict(:u1=>Set([:u5]),:u2=>Set([:u6]))
        if name == "without_hSelf"
            @test :u3 in measured.model.kappa
            @test :u3 in measured.collective
            @test all(:u3 ∉ image for image in values(measured.model.pi))
        end
        row = ModelAudit.circuit_measurement_report(measured)
        @test ModelAudit.verify_measurement_report(row)
        row["name"] = name
        row["construction_origin"] = "explicit_construction"
        row["expected"] = collect(expected)
        row["adjunction_holds"] = bg.holds
        row["checked_subset_pairs"] = bg.checked_pairs
        push!(rows,row)
        println(name," DC=",expected," M2=true; K=",ModelAudit._audit_names(measured.model.kappa))
    end
end
open(joinpath(@__DIR__,"explicit-two-input-witnesses.toml"),"w") do io
    TOML.print(io,Dict("schema_version"=>1,"phenomenal_claim"=>"not_certified", "execution_certified"=>false,
        "remaining_measured_patterns"=>["without_hSMC","without_hAct"],"witnesses"=>rows);sorted=true)
end
