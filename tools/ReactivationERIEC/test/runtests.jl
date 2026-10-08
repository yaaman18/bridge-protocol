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

# Classification of the analysis plan v2 draft [redundancy] (user decisions of 2026-10-07), written
# from the plan text: the hSelf part uses hSelf_T, hSMC and hAct keep their masks.
function classify(v, d)
    v["dc"] && return "pass"
    v["hBound"] && (v["hSelf"] || d["hSelf_T"]) && (v["hSMC"] || !isempty(d["mask_smc"])) &&
        (v["hAct"] || !isempty(d["mask_act"])) ? "fail_redundancy_ambiguous" : "fail"
end
dc_T(v, d) = d["hSelf_T"] && v["hSMC"] && v["hAct"] && v["hBound"]

# Independent hSelf_T: bit masks only. The record's loss sets are recomputed here from future_persistent
# (every silencing set), not read from the record.
function direct_hself_t(sub, record)
    n, O = sub.n, sub.outputs
    K = record["kappa"]; keep = K | (record["epsilon"] & sub.inputs)
    base = record["future_persistent"][1]
    loss(mask) = base & ~record["future_persistent"][mask + 1]
    rho = [loss(1 << i) & O for i in 0:(n - 1)]
    pi = [(O >> i) & 1 == 1 ? loss(1 << i) : 0 for i in 0:(n - 1)]
    phi = star(pi, star(rho, K, n), n)
    all(bits(K, n)) do c
        (phi >> c) & 1 == 1 && return true
        lost_single = any(i -> (loss(1 << i) >> c) & 1 == 1, 0:(n - 1))
        lost_single && return false
        minimal = [a for a in 1:((1 << n) - 1) if (loss(a) >> c) & 1 == 1 &&
                   !any(b -> b != a && b & a == b && (loss(b) >> c) & 1 == 1, 1:a)]
        !isempty(minimal) && all(a -> a & keep != 0, minimal)
    end
end

# ---------------------------------------------------------------------------------------------
# RSB-ANALYZE-001

const KNOWN = joinpath(REPO, "tools", "model_audit", "fixtures", "dc2-known-differences.toml")

# A scratch analysis plan v2 whose bindings carry the real result keys (OIDs are not read by the analysis).
function scratch_plan_v2(path)
    draft = read(PLAN_V2, String)
    filled = replace(draft, "package_tree_oid = \"PENDING-RSB-003\"" => "package_tree_oid = \"" * "a"^40 * "\"")
    filled = replace(filled, "profile_id = \"reactivation-substrate-v1\"" => "profile_id = \"scratch-fixture-01\"")
    write(path, filled)
    path
end

function analysis_checks(root, out, profile)
    plan = scratch_plan_v2(joinpath(root, "scratch-plan-v2.toml"))
    analyze(dir) = RE.analyze_run(dir; profile_path=profile, plan_path=plan, known_differences_path=KNOWN)
    report = analyze(out)
    @test report["status"] == "analyzed" && report["phenomenal_claim"] == "not_certified"
    # Independent recount from the result files.
    ids = TOML.parsefile(joinpath(out, "run-start.toml"))["case_ids"]
    dc = [TOML.parsefile(joinpath(out, "criteria", "dc", c * ".toml")) for c in ids]
    dc2 = [TOML.parsefile(joinpath(out, "criteria", "dc2", c * ".toml")) for c in ids]
    passes = sum(r["values"]["dc"] ? 1 : 0 for r in dc)
    T = [r["diagnostics"]["hSelf_T"] && r["values"]["hSMC"] && r["values"]["hAct"] && r["values"]["hBound"] for r in dc]
    @test report["dc"]["case_count"] == length(ids) && report["dc"]["pass_count"] == passes
    @test report["dc"]["dc_T_pass_count"] == count(T)
    @test report["dc"]["discrimination_rejects_substrate"] == (passes == 0 || passes == length(ids))
    @test sum(values(report["dc"]["classification_counts"])) == length(ids)
    @test report["dc2"]["pass_count"] == count(r -> r["values"]["dc2"], dc2)
    @test report["n3_unit_informativeness"]["v4_pairs"] >= 0
    # The report is a deterministic function of its inputs.
    @test analyze(out) == report

    # Stop and retraction conditions on tampered copies of the run.
    function tampered(name, change)
        dir = joinpath(root, "tampered-" * name)
        cp(out, dir)
        change(dir)
        analyze(dir)
    end
    edit(dir, id, case, f) = (p = joinpath(dir, "criteria", id, case * ".toml"); d = TOML.parsefile(p); f(d);
                              open(io -> TOML.print(io, d; sorted=true), p, "w"))
    @test tampered("no-completion", d -> rm(joinpath(d, "completion.toml")))["status"] == "not_analyzed"
    @test tampered("missing-case", d -> rm(joinpath(d, "cases", ids[end] * ".toml")))["status"] == "not_analyzed"
    @test tampered("extra-key", d -> edit(d, "dc", ids[2], r -> (r["diagnostics"]["extra"] = 1)))["status"] == "not_analyzed"
    zero = only(c for c in ids if TOML.parsefile(joinpath(out, "cases", c * ".toml"))["q"] == 0)
    r = tampered("all-off", d -> edit(d, "dc", zero, r -> (r["values"]["dc"] = true)))
    @test r["status"] == "run_retracted" && any(x -> occursin("ALL-OFF", x), r["reasons"])
    r = tampered("isolated", d -> edit(d, "dc", ids[3], r -> (r["values"]["dc"] = true; r["diagnostics"]["boundary"] = String[])))
    @test r["status"] == "run_retracted" && any(x -> occursin("ISOLATED", x), r["reasons"])
    r = tampered("dc2-implies-dc", d -> begin
        edit(d, "dc2", ids[4], r -> (r["values"]["dc2"] = true; r["values"]["beta_nonempty"] = true))
        edit(d, "dc", ids[4], r -> (r["values"]["hSelf"] = false))
    end)
    @test r["status"] == "analyzed" && r["dc2"]["records_retracted"]
    r = tampered("dc2-beta", d -> begin
        edit(d, "dc2", ids[5], r -> (r["values"]["dc2"] = true; r["values"]["beta_nonempty"] = false))
        edit(d, "dc", ids[5], r -> (r["values"]["hSelf"] = true; r["values"]["hSMC"] = true; r["values"]["hAct"] = true))
    end)
    @test r["dc2"]["records_retracted"] && any(x -> occursin("beta empty", x), r["dc2"]["retraction_reasons"])
end

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
                d = judge(RE.DCCriterion(), r, s)["diagnostics"]
                d["hSelf_T"] == direct_hself_t(sub, r) || (mismatches += 1)
                got["hSelf"] && !d["hSelf_T"] && (mismatches += 1)     # hSelf ⇒ hSelf_T

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
            bad = 0; checked = 0; dc2_true = 0; rescued = 0; t_bad = 0
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
                # hSelf_T against the independent mask implementation, where rescues actually occur
                dd = judge(RE.DCCriterion(), r, s)["diagnostics"]
                dd["hSelf_T"] == direct_hself_t(sub, r) || (t_bad += 1)
                (dd["hSelf_T"] && !dc["hSelf"]) && (rescued += 1)
                dc2["values"]["dc2"] && (dc2_true += 1)
            end
            @test bad == 0 && t_bad == 0
            @test checked > 0 && dc2_true > 0
            domain == :four_unit_exhaustive && @test rescued > 0    # hSelf_T is not vacuous
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
        # REDUNDANCY: two loops, each produced through a motor, feed a constituent c. Units: e=u0 (input),
        # m1=u1 (motor), a=u2, m2=u3 (motor), b=u4, c=u5, d=u6 (threshold 2, stays off: graph boundary).
        # m1⇄a; m2 needs b and e (threshold 2), m2→b, m2→e (environment map); c is fed by m1 and m2.
        sub = RM.Substrate(7, [(1, 2, 1), (2, 1, 1), (4, 3, 1), (0, 3, 1), (3, 4, 1), (3, 0, 1),
                               (1, 5, 1), (3, 5, 1), (5, 6, 1)],
                           [1, 1, 1, 2, 1, 1, 2], 0b0000001, 0b0001010)
        r, s = case_and_structure(sub, PROTO, 0b0111111)
        @test r["kappa"] == 0b0111111
        @test (r["collective_only_loss"] >> 5) & 1 == 1          # c lost only jointly
        out = judge(RE.DCCriterion(), r, s)
        v, d = out["values"], out["diagnostics"]
        want = exp("FALSIFICATION-PLAN-REDUNDANCY")
        @test v["dc"] == want["dc"] && !v["hSelf"] && v["hSMC"] && v["hAct"] && v["hBound"]
        @test dc_T(v, d) == want["dc_T"]
        @test classify(v, d) == want["classification"]
        # UNMASKED: the same circuit without the sink d, so no core unit has an out-neighbour outside
        # the core (hBound false). hSelf_T is true, but redundancy cannot hide hBound: fail.
        sub = RM.Substrate(6, [(1, 2, 1), (2, 1, 1), (4, 3, 1), (0, 3, 1), (3, 4, 1), (3, 0, 1),
                               (1, 5, 1), (3, 5, 1)],
                           [1, 1, 1, 2, 1, 1], 0b000001, 0b001010)
        r, s = case_and_structure(sub, PROTO, 0b111111)
        out = judge(RE.DCCriterion(), r, s)
        v, d = out["values"], out["diagnostics"]
        want = exp("FALSIFICATION-PLAN-UNMASKED")
        @test d["hSelf_T"] && !v["hSelf"]
        @test v["dc"] == want["dc"] && v["hBound"] == want["hBound"] && classify(v, d) == want["classification"]
        # REDUNDANCY-UNMEDIATED: the RSB-PLAN-002 fixture. Loops 1⇄2 and 3⇄4 have no motor and both feed
        # the motor unit 5. mask_self is nonempty (the old over-estimate would call it ambiguous), but
        # hSelf fails because the loops are not produced through actions, so hSelf_T is false: fail.
        sub = RM.Substrate(6, [(1, 0, 1), (0, 1, 1), (3, 2, 1), (2, 3, 1), (0, 4, 1), (2, 4, 1), (0, 5, 1)],
                           [1, 1, 1, 1, 1, 2], 0b000001, 0b010000)
        r, s = case_and_structure(sub, PROTO, 0b011111)
        out = judge(RE.DCCriterion(), r, s)
        v, d = out["values"], out["diagnostics"]
        want = exp("FALSIFICATION-PLAN-REDUNDANCY-UNMEDIATED")
        @test !isempty(d["mask_self"]) && !d["hSelf_T"]
        @test v["dc"] == want["dc"] && classify(v, d) == want["classification"]
        # Without any redundancy (unit 3's edge to unit 5 removed) the case is not ambiguous either.
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
            analysis_checks(root, out, joinpath(f.runner, "specs", "scratch-profile.toml"))
        end
    end

    @testset "preflight lists what stops a registration" begin
        mktempdir() do repo
            git(args...) = run(setenv(`git -C $repo -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false $(collect(String, args))`,
                                      Dict(k => v for (k, v) in ENV if !startswith(k, "GIT_"))))
            git("init", "-q", "-b", "main")
            mkpath(joinpath(repo, "tools"))
            cp(joinpath(REPO, "tools", "ReactivationERIEC"), joinpath(repo, "tools", "ReactivationERIEC"))
            mkpath(joinpath(repo, "src")); write(joinpath(repo, "src", "stub.jl"), "# dependency path\n")
            mkpath(joinpath(repo, "specs")); write(joinpath(repo, "specs", "profile.toml"), scratch_profile())
            git("add", "-A"); git("commit", "-q", "-m", "package")
            oid = SR.tree_oid_at(repo, "HEAD", "tools/ReactivationERIEC")
            plan(; version_dc="dc-rsb003-v2") = begin
                t = read(scratch_plan_v2(joinpath(repo, "specs", "plan.toml")), String)
                t = replace(t, "package_tree_oid = \"" * "a"^40 * "\"" => "package_tree_oid = \"$oid\"")
                t = replace(t, "package_name = \"PENDING-RSB-003\"" => "package_name = \"ReactivationERIEC\"")
                t = replace(t, "package_path = \"PENDING-RSB-003\"" => "package_path = \"tools/ReactivationERIEC\"")
                t = replace(t, "criterion_version = \"PENDING-RSB-003\"" => "criterion_version = \"$version_dc\"", count=1)
                t = replace(t, "criterion_version = \"PENDING-RSB-003\"" => "criterion_version = \"dc2-m1r-n3-rsb003-v1\"", count=1)
                write(joinpath(repo, "specs", "plan.toml"), t)
            end
            check() = RE.preflight(repo; plan_path="specs/plan.toml", profile_path="specs/profile.toml")
            plan()
            r = check()
            @test r["ok"] && isempty(r["problems"])
            r["ok"] || foreach(p -> println("preflight problem: ", p), r["problems"])
            plan(; version_dc="dc-old")
            @test any(p -> occursin("defines version", p), check()["problems"])
            plan()
            open(io -> write(io, "# changed\n"), joinpath(repo, "tools", "ReactivationERIEC", "src", "dc.jl"), "a")
            @test any(p -> occursin("uncommitted", p), check()["problems"])
            git("add", "-A"); git("commit", "-q", "-m", "drift")
            @test any(p -> occursin("tree of tools/ReactivationERIEC", p), check()["problems"])
        end
    end

    @testset "v4 truth and known differences from case records equal the audit implementation" begin
        bad_pairs = 0; bad_class = 0; differences = 0
        classes = TOML.parsefile(KNOWN)["class"]
        for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 4000))
            ModelAudit.for_each_search_circuit(domain, limit, 20260910) do c, id
                n = length(c.units)
                idx(u) = findfirst(==(u), c.units) - 1
                sub = RM.Substrate(n, [(s - 1, t - 1, w) for (s, t, w) in c.edges], collect(c.thresholds),
                    foldl((m, u) -> m | (1 << idx(u)), c.inputs; init=0),
                    foldl((m, u) -> m | (1 << idx(u)), c.motors; init=0))
                q = foldl((m, i) -> c.initial[i] ? m | (1 << (i - 1)) : m, 1:n; init=0)
                r, s = case_and_structure(sub, RM.Protocol(c.P, c.L, c.H, c.R), q)
                audit = Set(Tuple(sort([idx(x) for x in p])) for p in ModelAudit.pair_organization(c).pairs)
                mine = RE.v4_pairs(r, sub.outputs, n)
                mine == audit || (bad_pairs += 1)
                n3 = Set(Tuple(sort([parse(Int, String(x)[2:end]) for x in p]))
                         for p in judge(RE.DC2Criterion(), r, s)["diagnostics"]["mutual_pairs"])
                m = ModelAudit.measure_circuit(c; all_interventions=false)
                loss(u) = m.losses[1 << (findfirst(==(u), c.units) - 1)]
                for (kind, diff) in (("pair_missed_by_N3", setdiff(mine, n3)), ("pair_extra_in_N3", setdiff(n3, mine)))
                    for p in diff
                        differences += 1
                        a = ModelAudit.classify_difference(kind, [c.units[i + 1] for i in p], c.motors, loss, classes)
                        b = RE.classify_record_difference(kind, p, r, sub.outputs, n, classes)
                        a == b || (bad_class += 1)
                    end
                end
            end
        end
        @test bad_pairs == 0 && bad_class == 0
        @test differences > 0                                    # the classification is exercised
    end
end
