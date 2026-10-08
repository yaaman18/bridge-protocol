# RSB-002 and RSB-GEN-001 tests. Run in isolation:
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

# The RSB-002 engine before the RSB-GEN-001 split, kept verbatim as the golden reference.
include(joinpath(@__DIR__, "legacy_engine.jl"))

# Test-only stand-ins that carry the registered criterion NAMES "dc" and "dc2". They are not DC
# or DC2: their label records the defining module (StandIn), so a run made with them is visible
# as such in its run-start record. Real DC and DC2 criteria are RSB-003.
module StandIn
using ReactivationMeasurement
const RM = ReactivationMeasurement
struct Criterion <: RM.AbstractCriterion
    id::String
end
RM.criterion_id(c::Criterion) = c.id
RM.criterion_version(::Criterion) = "stand-in-0"
RM.required_structure(::Criterion) = [:n]
RM.evaluate(::Criterion, record, structure) = Dict(
    "values" => Dict("kappa_nonempty" => record["kappa"] != 0),
    "diagnostics" => Dict("n" => structure[:n]))
const PAIR = [Criterion("dc"), Criterion("dc2")]
end

# Systems and criteria that break the contracts on purpose.
module Stubs
using ReactivationMeasurement
const RM = ReactivationMeasurement
mutable struct Counter <: RM.AbstractSystem   # hidden state: not deterministic
    calls::Int
end
RM.nunits(::Counter) = 3
RM.step(s::Counter, x::Integer, ::Integer) = (s.calls += 1; (Int(x) + s.calls) & 0b111)
struct Leaky <: RM.AbstractSystem end          # ignores silencing: rotates the state
RM.nunits(::Leaky) = 3
RM.step(::Leaky, x::Integer, ::Integer) = ((Int(x) << 1) | (Int(x) >> 2)) & 0b111
struct OutOfRange <: RM.AbstractSystem end
RM.nunits(::OutOfRange) = 2
RM.step(::OutOfRange, ::Integer, ::Integer) = 0b100

struct Peeking <: RM.AbstractCriterion end     # reads a structure entry it did not declare
RM.criterion_id(::Peeking) = "peeking"
RM.criterion_version(::Peeking) = "0"
RM.required_structure(::Peeking) = [:n]
RM.evaluate(::Peeking, record, structure) =
    Dict("values" => Dict("x" => structure[:outputs] != 0), "diagnostics" => Dict())
struct HoldsSystem <: RM.AbstractCriterion     # keeps the system to read its weights
    sys::RM.Substrate
end
RM.criterion_id(::HoldsSystem) = "holds-system"
RM.criterion_version(::HoldsSystem) = "0"
RM.required_structure(::HoldsSystem) = Symbol[]
RM.evaluate(c::HoldsSystem, record, structure) =
    Dict("values" => Dict("x" => !isempty(c.sys.edges)), "diagnostics" => Dict())
struct Drifting <: RM.AbstractCriterion        # not deterministic
    calls::Base.RefValue{Int}
end
RM.criterion_id(::Drifting) = "drifting"
RM.criterion_version(::Drifting) = "0"
RM.required_structure(::Drifting) = Symbol[]
RM.evaluate(c::Drifting, record, structure) =
    (c.calls[] += 1; Dict("values" => Dict("x" => isodd(c.calls[])), "diagnostics" => Dict()))
struct NotBoolean <: RM.AbstractCriterion end
RM.criterion_id(::NotBoolean) = "not-boolean"
RM.criterion_version(::NotBoolean) = "0"
RM.required_structure(::NotBoolean) = Symbol[]
RM.evaluate(::NotBoolean, record, structure) = Dict("values" => Dict("x" => 1), "diagnostics" => Dict())
struct Named <: RM.AbstractCriterion
    id::String
    version::String
    wants::Vector{Symbol}
end
RM.criterion_id(c::Named) = c.id
RM.criterion_version(c::Named) = c.version
RM.required_structure(c::Named) = c.wants
RM.evaluate(::Named, record, structure) = Dict("values" => Dict("x" => true), "diagnostics" => Dict())
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
            ["ReactivationMeasurement.jl", "cellular.jl", "criteria.jl", "formats.jl", "records.jl",
             "response.jl", "run.jl", "substrate.jl", "system.jl"]
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
            # CRITERION-MISMATCH: the scratch plan records ["dc", "dc2"]. Anything else is refused
            # before any output is created.
            for bad in (RM.AbstractCriterion[], [StandIn.Criterion("dc")],
                        [StandIn.Criterion("dc"), StandIn.Criterion("other")],
                        [StandIn.Criterion("dc"), StandIn.Criterion("dc"), StandIn.Criterion("dc2")])
                out_bad = joinpath(root, "out-bad")
                @test_throws ArgumentError RM.start_run(token; runner_repo=f.runner,
                    run_id="scratch-run-00", out_dir=out_bad, criteria=bad)
                @test !ispath(out_bad)
            end
            @test_throws ArgumentError RM.start_run(token; runner_repo=f.runner, run_id="scratch-run-01",
                out_dir=joinpath(f.runner, "out"), criteria=StandIn.PAIR)
            out = joinpath(root, "out")
            manifest = RM.start_run(token; runner_repo=f.runner, run_id="scratch-run-01", out_dir=out,
                criteria=StandIn.PAIR)
            @test manifest["status"] == "complete"
            @test length(readdir(joinpath(out, "cases"))) == 16
            start = TOML.parsefile(joinpath(out, "run-start.toml"))
            @test start["criteria"] == RM.criterion_label.(StandIn.PAIR)
            @test all(l -> startswith(l, "dc") && occursin("|stand-in-0|", l) && endswith(l, "StandIn"),
                start["criteria"])
            profile = SR.validate_profile(read(joinpath(f.runner, "specs/scratch-profile.toml")))
            sub, proto = RM.substrate_from_profile(profile)
            legacy_sub = LegacyEngine.Substrate(sub.n, sub.edges, sub.thresholds, sub.inputs, sub.outputs)
            legacy_proto = LegacyEngine.Protocol(proto.preparation_steps, proto.kappa_points,
                proto.horizon, proto.effect_points)
            for id in token.case_ids
                rec = TOML.parsefile(joinpath(out, "cases", id * ".toml"))
                @test RM.validate_case_record(rec, sub, proto)
                expected = LegacyEngine.measure_case(legacy_sub, legacy_proto, rec["q"])
                expected["case_id"] = id
                @test rec == expected
                for cid in ("dc", "dc2")
                    res = TOML.parsefile(joinpath(out, "criteria", cid, id * ".toml"))
                    @test RM.validate_criterion_result(res)
                    @test res["case_id"] == id && res["criterion_id"] == cid
                    @test res["values"] == Dict("kappa_nonempty" => rec["kappa"] != 0)
                end
            end
            @test_throws ArgumentError RM.start_run(token; runner_repo=f.runner,
                run_id="scratch-run-02", out_dir=out, criteria=StandIn.PAIR)
        end
        # A profile that does not fix the output schema cannot be run.
        mktempdir() do root
            f = scratch_registration(root; v1=true)
            token = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
                remote_url=f.bare, remote_ref="refs/heads/main")
            @test token isa SR.VerifiedRegistration
            @test_throws ArgumentError RM.start_run(token; runner_repo=f.runner,
                run_id="scratch-run-03", out_dir=joinpath(root, "out"), criteria=StandIn.PAIR)
        end
    end

    @testset "GEN-GOLDEN: the split engine reproduces the RSB-002 engine byte for byte" begin
        seed = UInt64(0x2545f4914f6cdd1d)
        nx() = (seed = seed * 0x5851f42d4c957f2d + 0x14057b7ef767814f; seed >> 33)
        checked = 0
        for trial in 1:40
            n = 2 + Int(nx() % 5)
            edges = Tuple{Int,Int,Int}[]
            for s in 0:(n - 1), t in 0:(n - 1)
                s == t && continue
                r = nx() % 6
                r == 0 && push!(edges, (s, t, 1))
                r == 1 && push!(edges, (s, t, 2))
                r == 2 && push!(edges, (s, t, -1))
            end
            th = [1 + Int(nx() % 2) for _ in 1:n]
            ins = Int(nx() % (1 << n)); outs = Int(nx() % (1 << n)) & ~ins
            p = 1 + Int(nx() % 3); h = 1 + Int(nx() % 4)
            kp = 1 + Int(nx() % (p + 1)); ep = 1 + Int(nx() % h)
            new_sub = RM.Substrate(n, edges, th, ins, outs)
            old_sub = LegacyEngine.Substrate(n, edges, th, ins, outs)
            new_proto = RM.Protocol(p, kp, h, ep)
            old_proto = LegacyEngine.Protocol(p, kp, h, ep)
            for q in 0:((1 << n) - 1)
                a = RM.measure_case(new_sub, new_proto, q)
                b = LegacyEngine.measure_case(old_sub, old_proto, q)
                ia = IOBuffer(); TOML.print(ia, a; sorted=true)
                ib = IOBuffer(); TOML.print(ib, b; sorted=true)
                @test a == b
                @test take!(ia) == take!(ib)
                checked += 1
            end
        end
        @test checked == 848
    end

    @testset "GEN-ORDER: order-limited silencing and its scope" begin
        for n in 1:6, k in 1:n
            sets = RM.silencing_sets(n, k)
            @test length(sets) == sum(binomial(n, r) for r in 0:k)
            @test issorted(sets) && allunique(sets) && all(a -> count_ones(a) <= k, sets)
            @test all(a -> begin                       # downward closed
                        sub = a; ok = true
                        while true
                            ok &= insorted(sub, sets); sub == 0 && break; sub = (sub - 1) & a
                        end
                        ok
                    end, sets)
            k == n && @test sets == collect(0:((1 << n) - 1))
        end
        @test_throws ArgumentError RM.silencing_sets(4, 0)
        @test_throws ArgumentError RM.silencing_sets(4, 5)
        @test_throws ArgumentError RM.silencing_sets(40, 40)       # too many branches
        @test length(RM.silencing_sets(62, 1)) == 63               # large systems, singletons only

        seed = UInt64(0x9e3779b97f4a7c15)
        nx() = (seed = seed * 0x5851f42d4c957f2d + 0x14057b7ef767814f; seed >> 33)
        for trial in 1:8
            n = 5
            edges = Tuple{Int,Int,Int}[]
            for s in 0:(n - 1), t in 0:(n - 1)
                s == t && continue
                r = nx() % 5
                r == 0 && push!(edges, (s, t, 1))
                r == 1 && push!(edges, (s, t, 2))
                r == 2 && push!(edges, (s, t, -1))
            end
            sub = RM.Substrate(n, edges, [1 + Int(nx() % 2) for _ in 1:n], 0b00001, 0b10000)
            proto = RM.Protocol(2, 2, 4, 2)
            for q in 0:((1 << n) - 1)
                full = RM.measure_response(sub, proto, q)
                @test RM.is_exhaustive(full)
                for k in 1:(n - 1)
                    part = RM.measure_response(sub, proto, q; max_silencing_order=k)
                    @test !RM.is_exhaustive(part)
                    @test part.z == full.z && part.preparation_trace == full.preparation_trace
                    for (i, a) in enumerate(part.silencing_sets)
                        @test part.final[i] == full.final[a + 1]
                        @test part.persistent[i] == full.persistent[a + 1]
                    end
                    # Scope: exactly the globally minimal loss sets of size at most k.
                    for c in 0:(n - 1)
                        @test RM.minimal_loss_sets(part, c) ==
                            filter(a -> count_ones(a) <= k, RM.minimal_loss_sets(full, c))
                    end
                    # ORDER-SCOPE: the registered format refuses an order-limited table.
                    @test_throws ArgumentError RM.read_record(RM.RSBCaseRecordV1(), part, RM.roles(sub))
                    rec = RM.read_record(RM.ResponseRecordV1(), part)
                    @test RM.validate_response_record(rec)
                    @test rec["max_silencing_order"] == k
                end
                @test RM.read_record(RM.RSBCaseRecordV1(), full, RM.roles(sub)) == RM.measure_case(sub, proto, q)
            end
        end
        # Response records cannot overstate their scope.
        sub = circuit(5, Oracle.redundant_edges; outputs=0b10000)
        part = RM.measure_response(sub, RM.Protocol(2, 2, 4, 2), 0b11111; max_silencing_order=2)
        rec = RM.read_record(RM.ResponseRecordV1(), part)
        @test !haskey(rec, "loss_sets") && !haskey(rec, "collective_only_loss")
        bad = deepcopy(rec); bad["silencing_sets"] = collect(0:31)
        @test_throws ArgumentError RM.validate_response_record(bad)
        bad = deepcopy(rec); push!(bad["loss_sets_up_to_order"][1], 0b111)
        @test_throws ArgumentError RM.validate_response_record(bad)
        bad = deepcopy(rec); bad["loss_sets"] = bad["loss_sets_up_to_order"]
        @test_throws ArgumentError RM.validate_response_record(bad)
        # Redundancy is invisible to singletons: unit 5 is lost only when two supports go.
        single = RM.measure_response(sub, RM.Protocol(2, 2, 4, 2), 0b11111; max_silencing_order=1)
        @test isempty(RM.minimal_loss_sets(single, 4))
        @test RM.collective_only_loss(single) & 0b10000 == 0
        @test !isempty(RM.minimal_loss_sets(part, 4))
        @test RM.collective_only_loss(part) & 0b10000 != 0
    end

    @testset "GEN-SYSTEM: the system contract" begin
        @test RM.check_system_conformance(circuit(5, Oracle.redundant_edges; outputs=0b10000))
        @test RM.check_system_conformance(circuit(4, Oracle.feedforward_edges))
        # NONDETERMINISTIC, silencing leak, range: each contract breach is refused.
        @test_throws ArgumentError RM.check_system_conformance(Stubs.Counter(0))
        @test_throws ArgumentError RM.check_system_conformance(Stubs.Leaky())
        @test_throws ArgumentError RM.check_system_conformance(Stubs.OutOfRange())
        # SYSTEM-PEEK: a response table holds no system.
        @test all(T -> !(T <: RM.AbstractSystem), fieldtypes(RM.ResponseTable))
    end

    @testset "GEN-SECOND-SYSTEM: an elementary cellular automaton plugs in unchanged" begin
        ref_step(n, rule, x, silenced) = begin
            cells = [(x >> i) & 1 for i in 0:(n - 1)]
            sent = [((x & ~silenced) >> i) & 1 for i in 0:(n - 1)]
            next = 0
            for i in 1:n
                l = sent[mod1(i - 1, n)]; c = cells[i]; r = sent[mod1(i + 1, n)]
                idx = 4l + 2c + r
                (rule >> idx) & 1 == 1 && (next |= 1 << (i - 1))
            end
            next
        end
        for rule in (0, 30, 90, 110, 184, 204, 255)
            ca = RM.ElementaryCA(5, rule)
            @test RM.check_system_conformance(ca)
            for x in 0:31, sil in 0:31
                @test RM.step(ca, x, sil) == ref_step(5, rule, x, sil)
            end
        end
        # NO-FORCING: rule 204 copies each cell's own state, so silencing never zeroes a cell.
        id = RM.ElementaryCA(5, 204)
        @test all(RM.step(id, x, sil) == x for x in 0:31, sil in 0:31)
        @test_throws ArgumentError RM.ElementaryCA(2, 30)
        @test_throws ArgumentError RM.ElementaryCA(5, 256)
        ca = RM.ElementaryCA(6, 110)
        proto = RM.Protocol(3, 2, 5, 2)
        for q in 0:63
            full = RM.measure_response(ca, proto, q)
            part = RM.measure_response(ca, proto, q; max_silencing_order=2)
            @test RM.validate_response_record(RM.read_record(RM.ResponseRecordV1(), full))
            @test RM.validate_response_record(RM.read_record(RM.ResponseRecordV1(), part))
            # Roles are a reading, not a property of the system: they are passed in.
            rec = RM.read_record(RM.RSBCaseRecordV1(), full, (inputs=0b000011, outputs=0b110000))
            @test sort!(collect(keys(rec))) == sort(filter(!=("case_id"), RM.CASE_RECORD_FIELDS))
        end
        st = RM.declared_structure(ca, (inputs=0, outputs=0), [:out_adjacency])
        @test st[:out_adjacency][1] == 0b100010 && st[:out_adjacency][4] == 0b010100
    end

    @testset "GEN-CRITERIA: declared structure, identity, determinism, binding" begin
        sub = circuit(5, Oracle.redundant_edges; inputs=0b00001, outputs=0b10000)
        proto = RM.Protocol(2, 2, 4, 2)
        records = [(r = RM.measure_case(sub, proto, q); r["case_id"] = "case-$q"; r) for q in 0:31]
        # SYSTEM-PEEK: only declared entries exist.
        st = RM.declared_structure(sub, RM.roles(sub), [:n])
        @test collect(keys(st)) == [:n] && st[:n] == 5
        @test_throws ArgumentError st[:outputs]
        @test_throws ArgumentError RM.declared_structure(sub, RM.roles(sub), [:weights])
        full = RM.declared_structure(sub, RM.roles(sub), collect(RM.STRUCTURE_KEYS))
        @test full[:out_adjacency] == RM.out_adjacency(sub)
        cases = [(r, st) for r in records]
        @test RM.check_criterion_conformance(StandIn.Criterion("dc"), cases)
        @test_throws ArgumentError RM.check_criterion_conformance(Stubs.Peeking(), cases)
        @test_throws ArgumentError RM.check_criterion_conformance(Stubs.HoldsSystem(sub), cases)
        @test_throws ArgumentError RM.check_criterion_conformance(Stubs.Drifting(Ref(0)), cases)
        @test_throws ArgumentError RM.check_criterion_conformance(Stubs.NotBoolean(), cases)
        for (id, version, wants) in (("DC", "1", Symbol[]), ("dc", "", Symbol[]),
                                     ("dc", "1|x", Symbol[]), ("dc", "1", [:weights]))
            @test_throws ArgumentError RM.check_criterion_conformance(Stubs.Named(id, version, wants), cases)
        end
        res = RM.criterion_result(StandIn.Criterion("dc"), "case-3", records[4], st)
        @test RM.validate_criterion_result(res)
        bad = copy(res); bad["values"] = Dict{String,Any}()
        @test_throws ArgumentError RM.validate_criterion_result(bad)
        bad = copy(res); bad["extra"] = 1
        @test_throws ArgumentError RM.validate_criterion_result(bad)
        # CRITERION-MISMATCH: the run's criteria must equal the registered recorded_criteria.
        plan = Dict("interpretation" => Dict("recorded_criteria" => ["dc", "dc2"], "primary_criterion" => "dc"))
        @test RM.check_criteria_binding(plan, StandIn.PAIR)
        @test RM.check_criteria_binding(plan, reverse(StandIn.PAIR))
        for bad_set in (RM.AbstractCriterion[], [StandIn.Criterion("dc")],
                        [StandIn.Criterion("dc"), StandIn.Criterion("dc2"), StandIn.Criterion("x")],
                        [StandIn.Criterion("dc"), StandIn.Criterion("dc"), StandIn.Criterion("dc2")])
            @test_throws ArgumentError RM.check_criteria_binding(plan, bad_set)
        end
        other = Dict("interpretation" => Dict("recorded_criteria" => ["a", "b"], "primary_criterion" => "dc"))
        @test_throws ArgumentError RM.check_criteria_binding(other,
            [StandIn.Criterion("a"), StandIn.Criterion("b")])
        @test_throws ArgumentError RM.check_criteria_binding(plan, [Stubs.HoldsSystem(sub), StandIn.Criterion("dc2")])
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

# RSB-BIND-001 (needs the scratch helpers and StandIn defined above).
include(joinpath(@__DIR__, "scratch_registration.jl"))
include(joinpath(@__DIR__, "binding_v2.jl"))
