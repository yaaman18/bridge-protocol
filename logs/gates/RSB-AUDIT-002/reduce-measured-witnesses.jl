using TOML
using Test
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))

# Exploratory edge deletion. Thresholds, initial state, roles and windows stay fixed.
# "Minimal" means no single remaining edge can be deleted under these restrictions.
# It does not mean globally smallest, most plausible, or biologically validated.
function reduced_circuit(c, edges)
    ModelAudit.AuditCircuit(units=c.units, motors=c.motors, inputs=c.inputs,
        edges=edges, thresholds=c.thresholds, initial=c.initial, P=c.P,H=c.H,L=c.L,R=c.R)
end

rows = Dict{String,Any}[]
@testset "exploratory witness reduction and full-subset replay" begin
    corpus = ModelAudit.measured_witness_corpus()
    for original in corpus["witnesses"]
        current = ModelAudit.parse_audit_circuit(original["circuit"])
        expected = Tuple(original["expected"])
        attempts = Dict{String,Any}[]
        accepts(m) = m.result.valid && m.result.nondegenerate && m.result.actual == expected &&
                     (!expected[4] || m.active_boundary)
        while true
            changed = false
            for edge in current.edges
                candidate = reduced_circuit(current, filter(!=(edge), current.edges))
                measured = ModelAudit.measure_circuit(candidate; all_interventions=false)
                accepted = accepts(measured)
                push!(attempts, Dict("removed_edge" => collect(edge), "accepted" => accepted,
                    "before_digest" => ModelAudit._audit_digest(ModelAudit.circuit_dict(current)),
                    "after_digest" => ModelAudit._audit_digest(ModelAudit.circuit_dict(candidate)),
                    "actual" => collect(measured.result.actual),
                    "nondegenerate" => measured.result.nondegenerate, "active_boundary" => measured.active_boundary))
                if accepted
                    current = candidate
                    changed = true
                    break # Restart so previously rejected deletions are reconsidered.
                end
            end
            changed || break
        end
        full = ModelAudit.measure_circuit(current)
        @test accepts(full)
        @test full.all_interventions
        for edge in current.edges
            @test !accepts(ModelAudit.measure_circuit(reduced_circuit(current, filter(!=(edge), current.edges))))
        end
        result = ModelAudit.circuit_measurement_report(full)
        @test ModelAudit.verify_measurement_report(result)
        result["name"] = original["name"]
        result["expected"] = original["expected"]
        result["original_circuit_digest"] = original["circuit_digest"]
        result["reduction_attempts"] = attempts
        result["minimality_scope"] = "single_edge_deletion_fixed_roles_thresholds_initial_windows"
        push!(rows, result)
        println(original["name"], ": ", length(original["circuit"]["edges"]), " -> ", length(current.edges), " edges; ", expected)
    end
end
open(joinpath(@__DIR__, "reduced-witness-corpus-report.toml"), "w") do io
    TOML.print(io, Dict("schema_version" => 1, "phenomenal_claim" => "not_certified", "execution_certified" => false,
        "global_minimality" => "not_established", "witnesses" => rows); sorted=true)
end
