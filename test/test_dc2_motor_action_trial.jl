using Test
using ERIEC
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

# Trial environment for decision (D) (logs/gates/DC2-D-20261002/README.md). The trial readings are
# separate functions; the default measurement and check_dc2 are not changed.

function trial_case(domain, case)
    found = nothing
    ModelAudit.for_each_search_circuit(domain, case + 1, 20260910) do c, id
        id == case && (found = ModelAudit.measure_circuit(c; all_interventions=false))
    end
    found
end

@testset "trial readings are defined as reported and leave the default alone" begin
    m = trial_case(:four_unit_exhaustive, 5361)
    before = deepcopy(m.model)
    d = ModelAudit.motor_action_variant(m)
    s = ModelAudit.motor_self_production_variant(m)
    @test m.model == before                                   # the measured model is not mutated
    for u in keys(m.model.rho)
        extra = (u in m.model.M && u in m.baseline) ? Set([u]) : Set{Symbol}()
        @test d.rho[u] == union(m.model.rho[u], extra)        # ρ'(c) = (loss(c) ∩ M) ∪ ({c} ∩ M ∩ baseline)
        @test s.rho[u] == d.rho[u]
    end
    for a in keys(m.model.pi)
        @test d.pi[a] == m.model.pi[a]                        # (D) leaves π alone
        @test s.pi[a] == union(m.model.pi[a], a in m.baseline ? Set([a]) : Set{Symbol}())   # π''
    end
    @test (d.kappa, d.epsilon, d.alpha, d.sigma) == (m.model.kappa, m.model.epsilon, m.model.alpha, m.model.sigma)
end

@testset "templates: every reading agrees with the v2 labels" begin
    for t in ModelAudit.organization_templates(2)
        m = ModelAudit.measure_circuit(ModelAudit.template_circuit(t); all_interventions=false)
        for model in (m.model, ModelAudit.motor_action_variant(m), ModelAudit.motor_self_production_variant(m))
            @test ModelAudit.check_dc2(model).hUnit == t["G"]
        end
    end
end

@testset "what each reading changes on the inspected circuits" begin
    for (domain, case) in ((:four_unit_exhaustive, 5361), (:six_unit_sequence, 1150))
        m = trial_case(domain, case)
        @test !ModelAudit.check_dc2(m.model).hUnit
        @test !ModelAudit.check_dc2(ModelAudit.motor_action_variant(m)).hUnit           # ρ alone: no change
        @test ModelAudit.check_dc2(ModelAudit.motor_self_production_variant(m)).hUnit   # with π'': found
    end
    # Side effect of π'': an active motor maintains itself without the hinge, so HingeNeeded fails.
    m = trial_case(:four_unit_exhaustive, 884)
    @test ModelAudit.check_dc2(m.model).hHingeNeeded
    @test !ModelAudit.check_dc2(ModelAudit.motor_self_production_variant(m)).hHingeNeeded
end
