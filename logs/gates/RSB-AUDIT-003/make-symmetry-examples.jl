using TOML
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))

function pair(initial)
    ModelAudit.AuditCircuit(units=(:e1,:m1,:e2,:m2), motors=(:m1,:m2), inputs=(:e1,:e2),
        edges=((1,2,1),(2,1,1),(3,4,1),(4,3,1)), thresholds=(1,1,1,1),
        initial=initial, P=6,H=6,L=4,R=4)
end
supports = ((:e1,:m1),(:e2,:m2))
rows = Dict{String,Any}[]
for (name, initial, include_initial) in (
    ("symmetric_initial", (true,true,true,true), true),
    ("asymmetric_initial_included", (true,true,false,false), true),
    ("asymmetric_initial_omitted", (true,true,false,false), false))
    result = ModelAudit.symmetry_audit_report(ModelAudit.audit_candidate_supports(pair(initial), supports; include_initial))
    result["name"] = name
    push!(rows, result)
end
open(joinpath(@__DIR__, "symmetry-examples.toml"), "w") do io
    TOML.print(io, Dict("schema_version" => 1, "phenomenal_claim" => "not_certified", "examples" => rows); sorted=true)
end
for row in rows
    println(row["name"], ": ", row["automorphism_count"], " automorphisms; ", row["classification"])
end
