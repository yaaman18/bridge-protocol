using TOML
include("/Users/yamaguchimitsuyuki/bridge-protocol/tools/ModelAudit.jl")
const MA = ModelAudit
pat(name) = collect(only(p for p in MA.DC2_PATTERNS if p.name == name).values)
abstract = Any[]
c3 = MA.dc2_carrier_enumeration()
for name in ("all_four", "without_hSMC", "without_hUnit")
    push!(abstract, Dict("name"=>"c3-"*replace(name, "_"=>"-"), "nC"=>3, "nM"=>2, "nE"=>1,
        "encoding"=>c3.first_nondeg[name], "expected"=>pat(name), "selection"=>"first_nondegenerate_in_full_enumeration"))
end
push!(abstract, Dict("name"=>"c3-dc2-kappa-all", "nC"=>3, "nM"=>2, "nE"=>1,
    "encoding"=>c3.first_dc2_kappa_all, "expected"=>pat("all_four"), "selection"=>"first_dc2_with_kappa_all_constituents"))
c4 = MA.dc2_carrier_sample(4, 2, 1; samples=3_000_000, seed=20260930)
for p in MA.DC2_PATTERNS
    push!(abstract, Dict("name"=>"c4-"*replace(p.name, "_"=>"-"), "nC"=>4, "nM"=>2, "nE"=>1,
        "encoding"=>c4.first_nondeg[p.name], "expected"=>collect(p.values),
        "selection"=>"first_nondegenerate_in_seeded_sample"))
end
measured = Any[]
for domain in (:four_unit_exhaustive, :six_unit_sequence)
    s = MA.dc2_measured_search(domain)
    for (name, case_id) in s.first_nondeg
        circ = nothing
        MA.for_each_search_circuit(domain, case_id + 1, 20260910) do c, id
            id == case_id && (circ = c)
        end
        push!(measured, Dict("name"=>"$(domain)-$(replace(name, "_"=>"-"))", "source_domain"=>String(domain),
            "source_case_id"=>case_id, "seed"=>20260910, "expected"=>pat(name),
            "circuit"=>MA.circuit_dict(circ)))
    end
end
data = Dict("schema_version"=>1, "phenomenal_claim"=>"not_certified",
    "c4_sample"=>Dict("samples"=>3_000_000, "seed"=>20260930),
    "lean_references"=>[m.name for m in MA.lean_reference_m1r()],
    "abstract"=>abstract, "measured"=>measured)
open(io -> TOML.print(io, data; sorted=true), "/Users/yamaguchimitsuyuki/bridge-protocol/tools/model_audit/fixtures/dc2-witnesses.toml", "w")
