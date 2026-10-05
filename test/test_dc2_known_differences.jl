using Test
using TOML
using ERIEC
isdefined(@__MODULE__, :ModelAudit) || include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

# Known differences between N3 and the v4 truth (user decision 2026-10-04,
# tools/model_audit/fixtures/dc2-known-differences.toml).

function kd_case(domain, case)
    found = nothing
    ModelAudit.for_each_search_circuit(domain, case + 1, 20260910) do c, id
        id == case && (found = ModelAudit.measure_circuit(c; all_interventions=false))
    end
    found
end
kd_loss(m) = u -> m.losses[1 << (findfirst(==(u), m.circuit.units) - 1)]

@testset "registry" begin
    classes = ModelAudit.known_differences()
    @test [c["id"] for c in classes] == ["D_MOTOR_NOT_SELF_LOST", "ONE_LEG_ACTION", "N3_LOSS_COMPOSITION_EXTRA"]
    @test [c["status"] for c in classes] == ["accepted", "accepted", "pending"]
end

@testset "each exemplar falls in its class" begin
    for (domain, case, kind, pair, class) in (
            (:four_unit_exhaustive, 5361, "pair_missed_by_N3", [:u2, :u3], "D_MOTOR_NOT_SELF_LOST"),
            (:six_unit_sequence, 4862, "pair_missed_by_N3", [:u3, :u4], "ONE_LEG_ACTION"),
            (:six_unit_sequence, 1600, "pair_extra_in_N3", [:u4, :u5], "N3_LOSS_COMPOSITION_EXTRA"))
        m = kd_case(domain, case)
        @test ModelAudit.classify_difference(kind, pair, m.circuit.motors, kd_loss(m)) == class
        # With no registered class the same difference is unclassified, so it would be reported.
        @test ModelAudit.classify_difference(kind, pair, m.circuit.motors, kd_loss(m), []) == "UNCLASSIFIED"
    end
end

@testset "both search domains: every difference is classified; the pending class is reported" begin
    r = ModelAudit.known_difference_report()
    four, six = r["domains"]
    @test four["difference_counts"] == Dict("D_MOTOR_NOT_SELF_LOST" => 48)
    @test six["difference_counts"] == Dict("D_MOTOR_NOT_SELF_LOST" => 52, "ONE_LEG_ACTION" => 16,
                                           "N3_LOSS_COMPOSITION_EXTRA" => 12)
    @test r["reported_classes"] == ["N3_LOSS_COMPOSITION_EXTRA"] && r["report_to_user"]
    @test four["accepted_share_of_v4_pairs"] == 48 / four["v4_pairs"]
    @test r["phenomenal_claim"] == "not_certified"
end
