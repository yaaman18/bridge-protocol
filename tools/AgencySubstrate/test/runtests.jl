# Tests of the AGENCY-001 prototype substrate (gate 2 of specs/packets/AGENCY-001.md) and of the
# criteria against the frozen template labels (gate 3).
using AgencySubstrate, Test, TOML, SHA
const AS = AgencySubstrate

const FIXTURES = joinpath(@__DIR__, "..", "fixtures")
const GATES = joinpath(@__DIR__, "..", "..", "..", "logs", "gates", "AGENCY-001")
const SETS = [("templates.toml", "freeze.txt"),
              ("templates-adversarial.toml", "freeze-adversarial.txt"),
              ("templates-adversarial-2.toml", "freeze-adversarial-2.txt"),
              ("templates-adversarial-3.toml", "freeze-adversarial-3.txt"),
              ("templates-adversarial-4.toml", "freeze-adversarial-4.txt"),
              ("templates-repair.toml", "freeze-repair.txt")]
# Labels of the deepened L3 (self-repair) for the templates written before it.
const REPAIR_LABELS = joinpath(FIXTURES, "labels-repair.toml")

base = load_templates()
byname(set, n) = only(t for t in set.templates if t.name == n).substrate
reflex = byname(base, "reflex")
p1 = only(x for x in base.survival if x.name == "p1-high")

@testset "AgencySubstrate" begin
    @testset "frozen labels" begin
        for (f, freeze) in SETS
            set = load_templates(joinpath(FIXTURES, f))
            @test occursin(set.sha256, read(joinpath(GATES, freeze), String))
        end
        @test occursin(bytes2hex(open(sha256, REPAIR_LABELS)), read(joinpath(GATES, "freeze-repair.txt"), String))
    end

    @testset "determinism" begin
        for (f, _) in SETS, t in load_templates(joinpath(FIXTURES, f)).templates, x in base.survival
            a = AS.run_trajectory(t.substrate, base.params, x)
            b = AS.run_trajectory(t.substrate, base.params, x)
            @test all(i -> a[i].active == b[i].active && a[i].strength == b[i].strength &&
                           a[i].resource == b[i].resource && a[i].dead == b[i].dead, eachindex(a))
        end
    end

    @testset "resource bookkeeping" begin
        # reflex: c1, c2 and m1 active from step 1; m1 harvests 5, three units cost 3, every edge
        # is already at smax so nothing is paid for growth.
        traj = AS.run_trajectory(reflex, base.params, p1)
        @test [st.resource for st in traj] == [min(10 + 2t, base.params.rmax) for t in 0:base.params.horizon]
        # In general: resource never exceeds what harvesting minus activity allows.
        for (f, _) in SETS, t in load_templates(joinpath(FIXTURES, f)).templates, x in base.survival
            s = t.substrate
            tr = AS.run_trajectory(s, base.params, x)
            for k in 2:length(tr)
                tr[k].dead && break
                gain = sum((AS.yield_of(x, patch, k - 2) for (m, patch) in s.motors if tr[k].active[m]); init=0)
                @test tr[k].resource <= tr[k - 1].resource + gain - count(tr[k].active)
                @test tr[k].resource >= 0
            end
        end
    end

    @testset "silencing is source silencing only" begin
        m1 = findfirst(==("m1"), reflex.names)
        traj = AS.run_trajectory(reflex, base.params, p1; silenced=Set([m1]))
        # The silenced motor keeps updating its own state but harvests nothing: 10 - 3 per step.
        @test traj[2].active[m1]
        @test [st.resource for st in traj[1:4]] == [10, 7, 4, 1]
        @test traj[5].dead && !any(traj[5].active)
        # Death is absorbing, and a dead system's connections decay to nothing.
        @test all(st -> st.dead, traj[5:end])
        @test all(==(0), last(traj).strength)
    end

    @testset "structure given from outside never changes" begin
        s = byname(base, "static-agent")
        for x in base.survival, st in AS.run_trajectory(s, base.params, x)
            @test all(==(base.params.strength0), st.strength)
        end
    end

    @testset "verdicts agree with the frozen labels" begin
        l3r = TOML.parsefile(REPAIR_LABELS)["L3R"]
        for (f, _) in SETS
            set = load_templates(joinpath(FIXTURES, f))
            for t in set.templates
                r = evaluate(t.substrate, set)
                @test (t.name, r.agency) == (t.name, t.L2)
                @test (t.name, r.self_producing) == (t.name, t.L3)
                @test (t.name, r.self_repairing) == (t.name, something(t.L3R, get(l3r, t.name, missing)))
            end
        end
    end
end
