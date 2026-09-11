using Test
using TOML
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

function audit_circuit_fixture(; overrides...)
    old = ModelAudit.measured_dc_model()
    fields = merge((units=old.model.C, motors=old.model.M, inputs=old.model.E,
        edges=old.edges, thresholds=old.thresholds, initial=old.initial,
        P=old.P, H=old.H, L=old.L, R=old.R), (; overrides...))
    ModelAudit.AuditCircuit(; fields...)
end

@testset "circuit inputs and observational semantics" begin
    c = audit_circuit_fixture()
    old = ModelAudit.measured_dc_model()
    measured = ModelAudit.measure_circuit(c)
    @test measured.model == old.model
    @test measured.prefix == old.prefix && measured.traces == old.traces
    @test measured.result.actual == (true, true, true, true) && measured.active_boundary
    @test measured.all_interventions && length(measured.traces) == 64
    singles = ModelAudit.measure_circuit(c; all_interventions=false)
    @test singles.model == measured.model
    @test length(singles.traces) == 7 && !singles.all_interventions && singles.minima === nothing
    @test_throws ArgumentError ModelAudit.minimal_loss_masks(singles.losses, :e, 6)
    for state_mask in 0:63, source_mask in 0:63
        state = ntuple(i -> !iszero(state_mask & (1 << (i-1))), 6)
        e, core, m, a, b, d = ntuple(i -> state[i] && iszero(source_mask & (1 << (i-1))), 6)
        reference = (m, e, core, b, a, m && a)
        @test ModelAudit._audit_step(state, c.edges, c.thresholds, source_mask) == reference
    end
    data = ModelAudit.circuit_dict(c)
    restored = ModelAudit.parse_audit_circuit(data)
    @test ModelAudit.circuit_dict(restored) == data
    push!(data["edges"], [1, 4, 1])
    @test length(c.edges) == 7 # Caller mutation does not change the frozen circuit.
    for kwargs in ((P=-1,), (P=257,), (H=0,), (L=8,), (R=7,), (P=true,),
                   (thresholds=(1, 1, 1, 1, 1, 0),), (initial=(1, 1, 1, 1, 0, 0),),
                   (edges=[(1, 1, 1)],), (edges=[(1, 2, 0)],),
                   (edges=[(1, 2, 1), (1, 2, -1)],), (edges=[(2, 1, 1)],),
                   (edges=[(7, 2, 1)],), (motors=(:e,),),
                   (edges=[(1, 2, typemax(Int64)), (3, 2, 1)],),
                   (edges=[(1, 2, typemin(Int64))],))
        @test_throws ArgumentError audit_circuit_fixture(; kwargs...)
    end
    for key in ("extra", "schema_version")
        invalid = ModelAudit.circuit_dict(c)
        invalid[key] = true
        @test_throws ArgumentError ModelAudit.parse_audit_circuit(invalid)
    end
    losses = Dict(mask => Set{Symbol}() for mask in 0:7)
    losses[1] = Set([:x]); losses[7] = Set([:x])
    @test ModelAudit.minimal_loss_masks(losses, :x, 3) == (1,)
    empty!(losses[1]); losses[3] = Set([:x]); losses[5] = Set([:x])
    @test ModelAudit.minimal_loss_masks(losses, :x, 3) == (3, 5)
    # Two independent feedback pairs redundantly sustain their shared motor.
    redundant = ModelAudit.AuditCircuit(units=(:e, :m1, :a, :m2, :m3),
        motors=(:m1, :m2, :m3), inputs=(:e,), edges=((2,1,1),(1,2,1),(4,3,1),(3,4,1),(1,5,1),(3,5,1)),
        thresholds=(1,1,1,1,1), initial=(true,true,true,true,true), P=6,H=6,L=4,R=4)
    redundant_result = ModelAudit.measure_circuit(redundant)
    @test :m3 in redundant_result.collective
    @test Set(redundant_result.minima[:m3]) == Set((5, 6, 9, 10))
    @test all(:m3 ∉ redundant_result.model.rho[u] for u in redundant.units)
    # A negative input inhibits a target; silencing can increase future persistence.
    signed = audit_circuit_fixture(edges=[(3,1,1),(1,2,1),(2,3,1),(3,4,-1),(5,4,1),(4,5,1)])
    @test any(w < 0 for (_,_,w) in signed.edges)
    @test ModelAudit.measure_circuit(signed).result.valid
    for state_mask in 0:63, source_mask in 0:63
        state = ntuple(i -> !iszero(state_mask & (1 << (i-1))), 6)
        e, core, m, a, b, d = ntuple(i -> state[i] && iszero(source_mask & (1 << (i-1))), 6)
        @test ModelAudit._audit_step(state, signed.edges, signed.thresholds, source_mask) ==
              (m, e, core, b && !m, a, false)
    end
    report = ModelAudit.circuit_measurement_report(measured)
    @test ModelAudit.verify_measurement_report(report)
    for mutate in (
        r -> (r["actual"][1] = false),
        r -> (r["all_interventions"] = false),
        r -> (r["prefix"][1][1] = !r["prefix"][1][1]),
        r -> (r["traces"][1]["states"][2][1] = !r["traces"][1]["states"][2][1]),
        r -> (r["circuit_digest"] = repeat("0",64)),
        r -> (r["phenomenal_claim"] = "certified"),
        r -> (r["schema_version"] = true),
        r -> (r["extra"] = "ignored"),
    )
        changed = deepcopy(report)
        mutate(changed)
        @test_throws ArgumentError ModelAudit.verify_measurement_report(changed)
    end
    mktempdir() do dir
        path = joinpath(dir, "circuit.toml")
        open(io -> TOML.print(io, ModelAudit.circuit_dict(c); sorted=true), path, "w")
        root = dirname(@__DIR__)
        cli = joinpath(root, "bin", "eriec-model-audit.jl")
        output = read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli measure $path`, String)
        report = TOML.parse(output)
        @test report["actual"] == [true,true,true,true] && report["all_interventions"]
        @test report["phenomenal_claim"] == "not_certified" && !report["execution_certified"]
    end
end

@testset "bounded measured search never overstates coverage" begin
    search = ModelAudit.search_measured_models(limit=32)
    @test search.attempts == 32 && sum(values(search.counts)) == 32
    @test !search.exhaustive && !search.sequence_completed
    @test search.declared_cases == 32768
    @test ModelAudit.search_measured_models(limit=0).attempts == 0
    @test_throws ArgumentError ModelAudit.search_measured_models(limit=32769)
    @test_throws ArgumentError ModelAudit.search_measured_models(domain=:unknown)
    @test_throws ArgumentError ModelAudit.search_measured_models(seed=-1)
    a = ModelAudit.search_measured_models(domain=:six_unit_sequence, limit=32)
    b = ModelAudit.search_measured_models(domain=:six_unit_sequence, limit=32)
    @test ModelAudit.measured_search_report(a) == ModelAudit.measured_search_report(b)
    @test !a.exhaustive && a.declared_cases == 20000
    @test ModelAudit.measured_search_report(a)["general_impossibility"] == "not_established"
    report = ModelAudit.measured_search_report(search)
    @test ModelAudit.verify_search_report(report)
    false_coverage = deepcopy(report)
    false_coverage["exhaustive_in_declared_domain"] = true
    @test_throws ArgumentError ModelAudit.verify_search_report(false_coverage)
    # Inject a known circuit through the same acceptance/replay path as the search.
    counts, found = Dict{String,Int}(), Dict{String,Any}()
    ModelAudit._record_search_case!(counts, found, audit_circuit_fixture(), 7)
    @test counts["1111"] == 1
    @test found["all_four"].measurement.all_interventions
    @test found["all_four_active_boundary"].measurement.active_boundary
    @test found["all_four"].case_id == 7
end

@testset "frozen measured witnesses separate all four DC conditions" begin
    corpus = ModelAudit.measured_witness_corpus()
    @test corpus["all_expected_patterns_matched"] && !corpus["execution_certified"]
    @test length(corpus["witnesses"]) == 5
    @test Set(Tuple(row["actual"]) for row in corpus["witnesses"]) == Set(ModelAudit.AUDIT_TARGET_PATTERNS)
    for row in corpus["witnesses"]
        @test row["actual"] == row["expected"] && row["valid"] && row["nondegenerate"]
        @test row["all_interventions"]
        @test !row["actual"][4] || row["active_boundary"]
        circuit = ModelAudit.parse_audit_circuit(row["circuit"])
        measurement = ModelAudit.measure_circuit(circuit)
        @test all(measurement.model.rho[m] == intersect(measurement.model.pi[m], Set(circuit.motors)) for m in circuit.motors)
        @test all(image ⊆ measurement.baseline for image in values(measurement.model.pi))
        @test !measurement.result.actual[1] || measurement.model.kappa ⊆ measurement.baseline
    end
end
