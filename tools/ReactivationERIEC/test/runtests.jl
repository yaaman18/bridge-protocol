# RSB-003 gates (specs/packets/RSB-003.md §6). Run:
#   julia --startup-file=no --project=tools/ReactivationERIEC tools/ReactivationERIEC/test/runtests.jl
# Everything is synthetic or from the audit's declared search domains. The registered reactivation
# profile is never measured.

using Test
using SHA
using TOML
using ERIEC
using SubstrateRegistry
using ReactivationMeasurement
using ReactivationERIEC
const RM = ReactivationMeasurement
const SR = SubstrateRegistry
const RE = ReactivationERIEC

const REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
const PLAN_V2 = joinpath(REPO, "specs", "drafts", "reactivation-analysis-plan-v2.toml")
include(joinpath(REPO, "tools", "ModelAudit.jl"))          # the audit's circuits and DC/DC2

# ---------------------------------------------------------------------------------------------
# Helpers

bits(mask, n) = [i for i in 0:(n - 1) if (mask >> i) & 1 == 1]
star(rel, A, n) = foldl((acc, i) -> acc | rel[i + 1], bits(A, n); init=0)

function case_and_structure(sub, proto, q)
    record = RM.measure_case(sub, proto, q)
    record, RM.declared_structure(sub, RM.roles(sub), (:n, :inputs, :outputs, :out_adjacency))
end
judge(c, record, structure) = RM.criterion_result(c, "case", record, structure)

# Deterministic random substrate on n units: one input (unit 0), outputs from the last units,
# ordinary edges never enter the input, the environment map enters it from an output (always when
# `env`, so that cases with a nonempty ε, which exercise hSMC and the hinge, are frequent).
function random_substrate(seed, n; env=false)
    s = UInt64(seed)
    draw(k) = (s = s * 0x5851f42d4c957f2d + 0x14057b7ef767814f; Int((s >> 33) % UInt64(k)))
    outputs = (1 << (n - 1)) | (draw(2) == 0 ? 1 << (n - 2) : 0)
    edges = NTuple{3,Int}[]
    for a in 0:(n - 1), b in 1:(n - 1)
        a != b && (w = draw(4) - 1; w != 0 && w != 2 && push!(edges, (a, b, w)))
    end
    (draw(2) == 0 || env) && push!(edges, (n - 1, 0, 1))     # environment map: output → input
    RM.Substrate(n, edges, [1 + draw(2) for _ in 1:n], 1, outputs)
end
const PROTO = RM.Protocol(4, 3, 4, 2)

# Independent DC reference: bit masks only, no ERIEC, boundary read from the edge list.
function direct_dc(sub, record)
    n, I, O = sub.n, sub.inputs, sub.outputs
    K, eps = record["kappa"], record["epsilon"] & I
    rho = [record["rho"][i + 1] & O for i in 0:(n - 1)]
    pi = [(O >> i) & 1 == 1 ? record["pi"][i + 1] : 0 for i in 0:(n - 1)]
    alpha = [(O >> i) & 1 == 1 ? record["alpha"][i + 1] & I : 0 for i in 0:(n - 1)]
    sigma = [(I >> i) & 1 == 1 ? record["sigma"][i + 1] & O : 0 for i in 0:(n - 1)]
    hSelf = K & ~star(pi, star(rho, K, n), n) == 0
    hSMC = eps & ~star(alpha, star(sigma, eps, n), n) == 0
    act = star(rho, K, n) & star(sigma, eps, n)
    boundary = foldl((acc, e) -> (K >> e[1]) & 1 == 1 && (K >> e[2]) & 1 == 0 && e[3] != 0 ?
                     acc | (1 << e[1]) : acc, sub.edges; init=0)
    hBound = K & boundary != 0
    Dict("hSelf" => hSelf, "hSMC" => hSMC, "hAct" => act != 0, "hBound" => hBound,
         "dc" => hSelf && hSMC && act != 0 && hBound)
end

# RSB-PLAN-002 §5.3 classification, written from the packet text.
function classify(v, d)
    v["dc"] && return "pass"
    masks = Dict("hSelf" => d["mask_self"], "hSMC" => d["mask_smc"], "hAct" => d["mask_act"])
    v["hBound"] && all(k -> v[k] || !isempty(masks[k]), ("hSelf", "hSMC", "hAct")) ?
        "fail_redundancy_ambiguous" : "fail"
end

# ---------------------------------------------------------------------------------------------

@testset "RSB-003 DC and DC2 criteria" begin
    plan = TOML.parsefile(PLAN_V2)
    binding = Dict(b["criterion_id"] => b for b in plan["criterion_binding"])

    @testset "identity, conformance and the registered result keys" begin
        cases = [case_and_structure(random_substrate(k, 5), PROTO, q) for k in 1:4 for q in (0, 7, 31)]
        for (c, values, diags) in ((RE.DCCriterion(), RE.DC_VALUE_KEYS, RE.DC_DIAGNOSTIC_KEYS),
                                   (RE.DC2Criterion(), RE.DC2_VALUE_KEYS, RE.DC2_DIAGNOSTIC_KEYS))
            @test RM.check_criterion_conformance(c, [(r, s) for (r, s) in cases])
            @test endswith(RM.criterion_label(c), "|ReactivationERIEC")
            b = binding[RM.criterion_id(c)]
            @test sort(values) == sort(b["value_keys"]) && sort(diags) == sort(b["diagnostic_keys"])
            for (r, s) in cases
                out = judge(c, r, s)
                @test sort!(collect(keys(out["values"]))) == sort(values)
                @test sort!(collect(keys(out["diagnostics"]))) == sort(diags)
            end
        end
    end

    @testset "DC equals an independent mask implementation" begin
        mismatches = 0; seen = Dict(k => Set{Bool}() for k in ("dc", "hSelf", "hSMC", "hAct", "hBound"))
        eps_cases = 0
        for k in 1:60, n in (4, 5), env in (false, true)
            sub = random_substrate(1000k + n, n; env)
            for q in 0:((1 << n) - 1)
                r, s = case_and_structure(sub, PROTO, q)
                got = judge(RE.DCCriterion(), r, s)["values"]
                want = direct_dc(sub, r)
                r["epsilon"] & sub.inputs != 0 && (eps_cases += 1)
                got == want || (mismatches += 1)
                foreach(x -> push!(seen[x], want[x]), keys(seen))
            end
        end
        @test mismatches == 0
        @test all(v -> v == Set([true, false]), values(seen))    # not vacuous
        @test eps_cases >= 200                                    # hSMC exercised on nonempty ε
    end

    @testset "agreement with the finite-model audit on its search domains" begin
        # The same circuit measured by ModelAudit and by the engine: κ, DC and DC2 must agree.
        for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 4000))
            bad = 0; checked = 0; dc2_true = 0
            ModelAudit.for_each_search_circuit(domain, limit, 20260910) do c, id
                n = length(c.units)
                idx(u) = findfirst(==(u), c.units) - 1
                sub = RM.Substrate(n, [(s - 1, t - 1, w) for (s, t, w) in c.edges], collect(c.thresholds),
                    foldl((m, u) -> m | (1 << idx(u)), c.inputs; init=0),
                    foldl((m, u) -> m | (1 << idx(u)), c.motors; init=0))
                proto = RM.Protocol(c.P, c.L, c.H, c.R)
                q = foldl((m, i) -> c.initial[i] ? m | (1 << (i - 1)) : m, 1:n; init=0)
                r, s = case_and_structure(sub, proto, q)
                audit = ModelAudit.measure_circuit(c; all_interventions=false)
                rename(set) = Set(Symbol("u", parse(Int, String(x)[2:end]) - 1) for x in set)
                dc = judge(RE.DCCriterion(), r, s)["values"]
                dc2 = judge(RE.DC2Criterion(), r, s)
                a2 = ModelAudit.check_dc2(audit.model)
                ok = RE.erie_model(r, s).kappa == rename(audit.model.kappa) &&
                     (dc["hSelf"], dc["hSMC"], dc["hAct"], dc["hBound"]) == audit.result.actual &&
                     dc2["values"]["dc2"] == a2.dc2 && dc2["values"]["hUnit"] == a2.hUnit &&
                     dc2["values"]["hHingeNeeded"] == a2.hHingeNeeded && dc2["values"]["hSelf2"] == a2.hSelf2
                ok || (bad += 1)
                checked += 1
                dc2["values"]["dc2"] && (dc2_true += 1)
            end
            @test bad == 0
            @test checked > 0 && dc2_true > 0
        end
    end

    @testset "analysis plan v2 rows that waited for RSB-003" begin
        rows = Dict(r["id"] => r for r in plan["falsification"])
        exp(id) = rows[id]["expected_components"]
        # ALL-OFF: every unit off stays off (thresholds are positive).
        for k in 1:20
            r, s = case_and_structure(random_substrate(k, 5), PROTO, 0)
            v = merge(judge(RE.DCCriterion(), r, s)["values"], judge(RE.DC2Criterion(), r, s)["values"])
            @test all(v[key] == want for (key, want) in exp("FALSIFICATION-RSB-ALL-OFF"))
        end
        # DC2-IMPLIES-DC and DC2-GRAPH-BOUNDARY over many random cases.
        implies = exp("FALSIFICATION-RSB-DC2-IMPLIES-DC")
        graph = exp("FALSIFICATION-PLAN-DC2-GRAPH-BOUNDARY")
        dc2_cases = 0
        for k in 1:400, n in (4, 5), env in (false, true)
            sub = random_substrate(77k + n, n; env)
            for q in 0:((1 << n) - 1)
                r, s = case_and_structure(sub, PROTO, q)
                v = merge(judge(RE.DCCriterion(), r, s)["values"], judge(RE.DC2Criterion(), r, s)["values"])
                v["dc2"] || continue
                dc2_cases += 1
                @test all(v[key] == want for (key, want) in implies)
            end
        end
        @test dc2_cases > 0
        # DC2-GRAPH-BOUNDARY needs a core of every unit, which the random substrates never produce (the
        # input rarely persists). Fixture (RSB-PLAN-002 §10): input u0 is fed back from the output u2
        # through the environment map, and u1 needs both u0 and u2 (threshold 2), so the hinge matters.
        sub = RM.Substrate(3, [(0, 1, 1), (1, 2, 1), (2, 1, 1), (2, 0, 1)], [1, 2, 1], 0b001, 0b100)
        r, s = case_and_structure(sub, PROTO, 0b111)
        @test r["kappa"] == 0b111
        v = merge(judge(RE.DCCriterion(), r, s)["values"], judge(RE.DC2Criterion(), r, s)["values"])
        @test all(v[key] == want for (key, want) in graph)
        @test all(v[key] == want for (key, want) in implies)
        # REDUNDANCY: loops 1↔2 and 3↔4 both feed unit 5 (the output); a sixth unit with threshold 2
        # is reached from the core but stays off, so the graph boundary is nonempty.
        sub = RM.Substrate(6, [(1, 0, 1), (0, 1, 1), (3, 2, 1), (2, 3, 1), (0, 4, 1), (2, 4, 1), (0, 5, 1)],
                           [1, 1, 1, 1, 1, 2], 0b000001, 0b010000)
        r, s = case_and_structure(sub, PROTO, 0b011111)
        @test (r["collective_only_loss"] >> 4) & 1 == 1          # unit 5 lost only jointly
        out = judge(RE.DCCriterion(), r, s)
        want = exp("FALSIFICATION-PLAN-REDUNDANCY")
        @test out["values"]["dc"] == want["dc"]
        @test classify(out["values"], out["diagnostics"]) == want["classification"]
        # Without the redundancy (unit 3's edge to unit 5 removed) the case is a plain fail or pass.
        sub2 = RM.Substrate(6, [(1, 0, 1), (0, 1, 1), (3, 2, 1), (2, 3, 1), (0, 4, 1), (0, 5, 1)],
                            [1, 1, 1, 1, 1, 2], 0b000001, 0b010000)
        r2, s2 = case_and_structure(sub2, PROTO, 0b011111)
        out2 = judge(RE.DCCriterion(), r2, s2)
        @test classify(out2["values"], out2["diagnostics"]) != "fail_redundancy_ambiguous"
    end

    @testset "start_run end to end with the real criteria on a scratch registration" begin
        include(joinpath(REPO, "tools", "ReactivationMeasurement", "test", "scratch_registration.jl"))
        mktempdir() do root
            f = scratch_registration(root)
            token = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
                remote_url=f.bare, remote_ref="refs/heads/main")
            out = joinpath(root, "out")
            criteria = [RE.DCCriterion(), RE.DC2Criterion()]
            manifest = RM.start_run(token; runner_repo=f.runner, run_id="scratch-run-01", out_dir=out,
                criteria=criteria)
            @test manifest["status"] == "complete"
            start = TOML.parsefile(joinpath(out, "run-start.toml"))
            @test start["criteria"] == RM.criterion_label.(criteria)
            for id in ("dc", "dc2")
                files = readdir(joinpath(out, "criteria", id))
                @test length(files) == length(readdir(joinpath(out, "cases")))
                @test all(f -> RM.validate_criterion_result(TOML.parsefile(joinpath(out, "criteria", id, f))), files)
            end
        end
    end
end
