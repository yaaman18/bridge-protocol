# RSB-002 tests. Run in isolation:
#   JULIA_LOAD_PATH=@:@stdlib julia --startup-file=no --project=tools/ReactivationMeasurement \
#       tools/ReactivationMeasurement/test/runtests.jl
# Everything here is synthetic. The frozen reactivation profile is never measured (RSB-002 R1).

using Test
using SHA
using TOML
using SubstrateRegistry
using ReactivationMeasurement
const RM = ReactivationMeasurement
const SR = SubstrateRegistry

const PROJECT_DIR = normpath(joinpath(@__DIR__, ".."))
const REPO_DIR = normpath(joinpath(PROJECT_DIR, "..", ".."))

# The independent semantic fixtures of design-r2 §8 serve as the oracle. Loading them also
# re-runs their own 1391 checks.
module Oracle
include(joinpath(@__DIR__, "..", "..", "experiments", "reactivation_measurement_fixtures.jl"))
end

# Fixture circuits use 1-based unit numbers; the engine uses 0-based bit indices.
zero_based(edges) = [(s - 1, t - 1, w) for (s, t, w) in edges]
circuit(n, edges; thresholds=ones(Int, n), inputs=0, outputs=0) =
    RM.Substrate(n, zero_based(edges), thresholds, inputs, outputs)
tuple_of(mask, n) = ntuple(i -> (mask >> (i - 1)) & 1 == 1, n)
mask_of(set) = foldl((m, i) -> m | (1 << (i - 1)), set; init=0)
mask_of_tuple(x) = foldl((m, i) -> x[i] ? m | (1 << (i - 1)) : m, eachindex(x); init=0)

@testset "RSB-002 reactivation measurement" begin
    @testset "isolation from ERIEC (NO-DC)" begin
        @test Base.find_package("ERIEC") === nothing
        project = TOML.parsefile(joinpath(PROJECT_DIR, "Project.toml"))
        @test sort!(collect(keys(project["deps"]))) == ["SHA", "SubstrateRegistry", "TOML"]
        src = joinpath(PROJECT_DIR, "src")
        @test sort!(readdir(src)) ==
            ["ReactivationMeasurement.jl", "measure.jl", "records.jl", "run.jl", "substrate.jl"]
        for file in readdir(src; join=true), line in eachline(file)
            occursin(r"^\s*(using|import)\s", line) || continue
            @test occursin(r"^\s*(using|import)\s+(SHA|TOML|SubstrateRegistry)\s*$", line)
        end
        forbidden = r"check_dc|hself|hsmc|hact|hbound|erie_?state|boundary|dc2"i
        @test isempty(filter(n -> occursin(forbidden, String(n)), names(RM; all=true)))
        sub = circuit(2, Oracle.feedback_edges; outputs=2)
        proto = RM.Protocol(2, 2, 3, 2)
        record = RM.measure_case(sub, proto, 3)
        record["case_id"] = "case-3"
        @test RM.validate_case_record(record, sub, proto)
        for key in ("hSelf", "hBound", "act", "boundary")
            bad = copy(record); bad[key] = 0
            @test_throws ArgumentError RM.validate_case_record(bad, sub, proto)
        end
    end

    @testset "ORACLE: update rule against independent Boolean maps and weight sums" begin
        for (n, edges, reference) in ((3, Oracle.start_edges, Oracle.start_ref),
                                     (2, Oracle.feedback_edges, Oracle.feedback_ref),
                                     (4, Oracle.feedforward_edges, Oracle.feedforward_ref),
                                     (5, Oracle.redundant_edges, Oracle.redundant_ref))
            sub = circuit(n, edges)
            for bits in 0:((1 << n) - 1), mask in 0:((1 << n) - 1)
                @test RM.step(sub, bits, mask) == mask_of_tuple(reference(tuple_of(bits, n), mask))
            end
        end
    end

    @testset "ORACLE + MINIMALITY: whole observation on signed circuits" begin
        # Deterministic pseudo-random signed circuits; no stdlib Random dependency.
        seed = UInt64(0x9e3779b97f4a7c15)
        next!() = (seed = seed * 0x5851f42d4c957f2d + 0x14057b7ef767814f; seed >> 33)
        for trial in 1:12
            n = 4
            edges = Tuple{Int,Int,Int}[]
            for s in 1:n, t in 1:n
                s == t && continue
                r = next!() % 5
                r == 0 && push!(edges, (s, t, 1))
                r == 1 && push!(edges, (s, t, 2))
                r == 2 && push!(edges, (s, t, -1))
            end
            thresholds = [1 + Int(next!() % 2) for _ in 1:n]
            proto = RM.Protocol(2, 2, 4, 2)
            sub = circuit(n, edges; thresholds, inputs=0b0001, outputs=0b1000)
            ref_step = (x, mask) -> Oracle.threshold_step(x, edges, thresholds, mask)
            for q in 0:((1 << n) - 1)
                rec = RM.measure_case(sub, proto, q)
                obs = Oracle.observe(ref_step, tuple_of(q, n);
                    preparation=2, kappa_points=2, horizon=4, effect_points=2)
                @test rec["z"] == mask_of_tuple(obs.anchor)
                @test rec["kappa"] == mask_of(obs.kappa)
                @test rec["preparation_trace"] == mask_of_tuple.(obs.prefix)
                for a in 0:((1 << n) - 1)
                    @test rec["future_final"][a + 1] == mask_of_tuple(obs.branches[a][end])
                    @test (rec["future_persistent"][1] & ~rec["future_persistent"][a + 1]) ==
                        mask_of(obs.losses[a])
                end
                for c in 1:n
                    @test Set(rec["loss_sets"][c]) == Oracle.minimal_loss_masks(obs.losses, c)
                end
            end
        end
    end

    @testset "FIXTURES: design-r2 §8 expectations" begin
        # Startup-only seed.
        sub = circuit(3, Oracle.start_edges)
        rec = RM.measure_case(sub, RM.Protocol(2, 2, 4, 2), 0b100)
        @test rec["z"] == 0b011
        @test rec["future_persistent"][1] & ~rec["future_persistent"][0b100 + 1] == 0
        @test rec["future_final"][0b100 + 1] == rec["future_final"][1]
        # One output with real feedback loss including itself.
        sub = circuit(2, Oracle.feedback_edges; outputs=0b10)
        rec = RM.measure_case(sub, RM.Protocol(2, 2, 3, 2), 0b11)
        @test RM._trace(sub, rec["z"], 3, 0b10) == [0b11, 0b10, 0b00, 0b00]
        @test rec["pi"][2] == 0b11
        @test rec["rho"][1] == 0b10 && rec["rho"][2] == 0b10
        # NO-FORCING: a silenced source keeps its own state.
        sub = circuit(4, Oracle.feedforward_edges)
        rec = RM.measure_case(sub, RM.Protocol(2, 2, 3, 2), 0b1111)
        branch = RM._trace(sub, rec["z"], 3, 0b0100)
        @test branch[2] == 0b0111
        @test all(x -> x & 0b0100 != 0, branch)
        @test rec["pi"][3] == 0b1000
        # Redundant support: collective effect without a singleton effect.
        sub = circuit(5, Oracle.redundant_edges; outputs=0b10000)
        rec = RM.measure_case(sub, RM.Protocol(2, 2, 4, 2), 0b11111)
        @test rec["pi"][1] & 0b10000 == 0 && rec["pi"][3] & 0b10000 == 0
        @test sort(rec["loss_sets"][5]) == [5, 6, 9, 10]
        @test rec["collective_only_loss"] & 0b10000 != 0
        @test all(==(0), rec["rho"])
        # Minimality compares against every proper subset.
        loss = zeros(Int, 8); loss[1 + 1] = 0b1; loss[7 + 1] = 0b1
        @test RM._minimal_loss_sets(loss, 0) == [1]
        # Future rising is not capped by the pre-intervention kappa.
        sub = circuit(3, Oracle.start_edges)
        rec = RM.measure_case(sub, RM.Protocol(0, 1, 3, 2), 0b100)
        @test rec["kappa"] == 0b100
        @test rec["pi"][3] == 0b011
        # Changing the kappa window does not change the physical protocol.
        short = RM.measure_case(sub, RM.Protocol(2, 2, 4, 2), 0b100)
        long = RM.measure_case(sub, RM.Protocol(2, 3, 4, 2), 0b100)
        @test short["kappa"] == 0b011 && long["kappa"] == 0
        for key in ("z", "future_final", "future_persistent", "pi", "rho", "alpha", "sigma", "loss_sets")
            @test short[key] == long[key]
        end
        @test_throws ArgumentError RM.Protocol(2, 4, 4, 2)
        @test_throws ArgumentError RM.Protocol(2, 2, 4, 5)
    end

    @testset "SAME-BRANCH, RHO-PI, NO-WRITEBACK" begin
        sub = circuit(5, Oracle.redundant_edges; inputs=0b00001, outputs=0b10000)
        proto = RM.Protocol(2, 2, 4, 2)
        for q in 0:31
            rec = RM.measure_case(sub, proto, q)
            z = rec["z"]
            for a in 0:31
                @test RM._trace(sub, z, proto.horizon, a)[1] == z
            end
            @test all(c -> rec["rho"][c] == rec["pi"][c] & sub.outputs, 1:5)
            # The natural preparation trace is the unsilenced trace from q.
            @test rec["preparation_trace"] == RM._trace(sub, q, proto.preparation_steps, 0)
            # No hidden state: measuring other cases in between changes nothing.
            RM.measure_case(sub, proto, 31 - q)
            @test RM.measure_case(sub, proto, q) == rec
        end
    end

    @testset "TOKEN: start_run requires the verification capability" begin
        ms = collect(methods(RM.start_run))
        @test !isempty(ms)
        @test all(m -> m.sig.parameters[2] === SR.VerifiedRegistration, ms)
    end

    @testset "start_run end to end on a scratch registration" begin
        include(joinpath(@__DIR__, "scratch_registration.jl"))
        mktempdir() do root
            f = scratch_registration(root)
            token = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
                remote_url=f.bare, remote_ref="refs/heads/main")
            @test token isa SR.VerifiedRegistration
            @test_throws ArgumentError RM.start_run(token; runner_repo=f.runner, run_id="scratch-run-01",
                out_dir=joinpath(f.runner, "out"))
            out = joinpath(root, "out")
            manifest = RM.start_run(token; runner_repo=f.runner, run_id="scratch-run-01", out_dir=out)
            @test manifest["status"] == "complete"
            @test length(readdir(joinpath(out, "cases"))) == 16
            profile = SR.validate_profile(read(joinpath(f.runner, "specs/scratch-profile.toml")))
            sub, proto = RM.substrate_from_profile(profile)
            for id in token.case_ids
                rec = TOML.parsefile(joinpath(out, "cases", id * ".toml"))
                @test RM.validate_case_record(rec, sub, proto)
                expected = RM.measure_case(sub, proto, rec["q"])
                expected["case_id"] = id
                @test rec == expected
            end
            @test_throws ArgumentError RM.start_run(token; runner_repo=f.runner,
                run_id="scratch-run-02", out_dir=out)
        end
        # A profile that does not fix the output schema cannot be run.
        mktempdir() do root
            f = scratch_registration(root; v1=true)
            token = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
                remote_url=f.bare, remote_ref="refs/heads/main")
            @test token isa SR.VerifiedRegistration
            @test_throws ArgumentError RM.start_run(token; runner_repo=f.runner,
                run_id="scratch-run-03", out_dir=joinpath(root, "out"))
        end
    end

    @testset "NO-CANDIDATE-RUN: no measured records of the frozen profile" begin
        gate = joinpath(REPO_DIR, "logs", "gates", "RSB-002")
        found = String[]
        if isdir(gate)
            for (dir, _, files) in walkdir(gate), file in files
                occursin(r"^case-[0-9]+\.toml\z", file) && push!(found, joinpath(dir, file))
            end
        end
        @test isempty(found)
        for file in readdir(@__DIR__; join=true)
            @test !occursin("reactivation-substrate-" * "v1", read(file, String))
        end
    end
end
