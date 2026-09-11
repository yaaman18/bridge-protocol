using Test
using TOML
isdefined(@__MODULE__, :CountermodelAudit) || include(joinpath(@__DIR__,"..","tools","CountermodelAudit.jl"))

const P3_CONTEXT = ("two_inputs_two_motors_P3_H6_L4_R4",)
query(id,premises,conclusion;contexts=P3_CONTEXT) = CountermodelAudit.CountermodelQuery(
    query_id=id,contexts=contexts,premises=Tuple(premises),conclusion=conclusion)

@testset "finite countermodels are evidence and absence is not a theorem" begin
    catalog = CountermodelAudit.finite_model_catalog()
    @test catalog["model_count"] == 13
    @test length(unique(row["circuit_digest"] for row in catalog["models"])) == 13
    @test all(!row["observations"]["all_dc"] || all(row["observations"][k] for k in ("hSelf","hSMC","hAct","hBound")) for row in catalog["models"])
    for (id,goal,expected_id) in (
        ("self-implies-smc", :hSMC=>true, "p3-adjoint-without_hSMC"),
        ("self-implies-act", :hAct=>true, "p3-adjoint-without_hAct"),
        ("dc-implies-k-equals-nu", :kappa_equals_nu=>true, "p3-adjoint-support-expansion"))
        result=CountermodelAudit.query_countermodels(query(id,(:adjunction=>true,:hSelf=>true),goal),catalog)
        @test result.classification == :counterexample_found && !result.implication_proved
        @test expected_id in getindex.(result.countermodels,"id")
    end
    symmetry = CountermodelAudit.query_countermodels(query("max-support-selects-component",
        (:adjunction=>true,:all_dc=>true,:kappa_equals_nu=>true),:candidate_selection_obstructed=>false),catalog)
    @test only(symmetry.countermodels)["id"] == "p3-adjoint-symmetric-union"
    @test length(symmetry.unknown) == symmetry.context_model_count-1
    absent = CountermodelAudit.query_countermodels(query("active-boundary-implied",
        (:all_dc=>true,),:active_boundary=>true;contexts=("one_input_one_motor_P6_H6_L4_R4",)),catalog)
    @test absent.classification == :not_found_in_finite_catalog
    @test !absent.implication_proved && absent.general_impossibility == :not_established
    @test_throws ArgumentError query("empty",(:hSelf=>true,),:hSMC=>true;contexts=())
    @test_throws ArgumentError query("repeat",(:hSelf=>true,),:hSelf=>false)
    @test_throws ArgumentError query("bad",(:unknown=>true,),:hSelf=>true)
    @test_throws ArgumentError CountermodelAudit.query_countermodels(query("missing",(),:hSelf=>true;contexts=("missing",)),catalog)
    data=Dict("schema_version"=>1,"query_id"=>"cli","contexts"=>collect(P3_CONTEXT),
        "premises"=>Dict("adjunction"=>true,"all_dc"=>true),"conclusion"=>Dict("kappa_equals_nu"=>true))
    parsed=CountermodelAudit.parse_countermodel_query(data)
    @test parsed.query_id == "cli"
    for mutate in (d->(d["schema_version"]=true),d->(d["extra"]="x"),
                   d->(d["conclusion"]["hSelf"]=true),d->(d["premises"]["bad"]=true))
        bad=deepcopy(data); mutate(bad)
        @test_throws ArgumentError CountermodelAudit.parse_countermodel_query(bad)
    end
    mktempdir() do dir
        path=joinpath(dir,"query.toml")
        open(io->TOML.print(io,data;sorted=true),path,"w")
        root=dirname(@__DIR__); cli=joinpath(root,"bin","eriec-countermodel-audit.jl")
        output=read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli query $path`,String)
        report=TOML.parse(output)
        @test report["classification"] == "counterexample_found"
        @test report["countermodel_count"] >= 1 && !report["implication_proved"]
        @test report["phenomenal_claim"] == "not_certified"
    end
end
