using TOML
using Test
include(joinpath(@__DIR__,"..","..","..","tools","BackgroundAudit.jl"))

function run_domain(n)
    attempts = 20000
    seed = 20260911 + n
    state = UInt64(seed)
    draw(k) = begin
        state = state * UInt64(6364136223846793005) + UInt64(1442695040888963407)
        Int((state >> 32) % UInt64(k))
    end
    units = ntuple(i -> Symbol("u$i"),n)
    motors,inputs = (units[n-1],units[n]),(units[1],units[2])
    allowed = [(s,d) for s in 1:n for d in 1:n if s != d && (d > 2 || s >= n-1)]
    counts,background_counts,found = Dict{String,Int}(),Dict{String,Int}(),Dict{String,Any}()
    background_total = 0
    for case_id in 0:(attempts-1)
        edges = NTuple{3,Int}[]
        for (s,d) in allowed
            w = draw(3)-1
            w == 0 || push!(edges,(s,d,w))
        end
        thresholds = ntuple(_ -> draw(2)+1,n)
        bits = draw(1 << n)
        c = ModelAudit.AuditCircuit(;units,motors,inputs,edges,thresholds,
            initial=ntuple(i -> !iszero(bits & (1 << (i-1))),n),P=6,H=6,L=4,R=4)
        measured = ModelAudit.measure_circuit(c; all_interventions=false)
        pattern = measured.result.actual
        key = join(Int.(pattern))
        counts[key] = get(counts,key,0)+1
        background = BackgroundAudit.check_adjunction_background(measured.model)
        background.holds || continue
        background_total += 1
        background_counts[key] = get(background_counts,key,0)+1
        measured.result.nondegenerate && pattern in ModelAudit.AUDIT_TARGET_PATTERNS || continue
        !pattern[4] || measured.active_boundary || continue
        name = ModelAudit._pattern_name(pattern)
        if !haskey(found,name)
            full = ModelAudit.measure_circuit(c)
            @test full.result.actual == pattern && full.result.valid && full.result.nondegenerate
            @test !pattern[4] || full.active_boundary
            bg = BackgroundAudit.check_adjunction_background(full.model)
            @test bg.holds && bg.checker_matched
            row = ModelAudit.circuit_measurement_report(full)
            @test ModelAudit.verify_measurement_report(row)
            row["case_id"] = case_id
            row["name"] = name
            row["adjunction_holds"] = true
            row["checked_subset_pairs"] = bg.checked_pairs
            found[name] = row
        end
    end
    println("N=",n," attempts=",attempts," M2_pass=",background_total," found=",join(sort!(collect(keys(found))),","))
    Dict("schema_version"=>1,"N"=>n,"attempts"=>attempts,"seed"=>seed,"adjunction_pass_count"=>background_total,
        "phenomenal_claim"=>"not_certified","execution_certified"=>false,"exhaustive"=>false,
        "background"=>"finite_relational_galois_connection","general_impossibility"=>"not_established",
        "all_pattern_counts"=>counts,"background_pattern_counts"=>background_counts,
        "unfound_patterns"=>[ModelAudit._pattern_name(p) for p in ModelAudit.AUDIT_TARGET_PATTERNS if !haskey(found,ModelAudit._pattern_name(p))],
        "witnesses"=>[found[k] for k in sort!(collect(keys(found)))])
end

@testset "two-input measured search with M2 background" begin
    for n in (6,7)
        result = run_domain(n)
        @test sum(values(result["all_pattern_counts"])) == result["attempts"]
        @test sum(values(result["background_pattern_counts"])) == result["adjunction_pass_count"]
        open(joinpath(@__DIR__,"search-two-input-$(n)-units.toml"),"w") do io
            TOML.print(io,result; sorted=true)
        end
    end
end
