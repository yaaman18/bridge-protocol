using TOML
base = @__DIR__
four = TOML.parsefile(joinpath(base, "search-four-unit.toml"))
six = TOML.parsefile(joinpath(base, "search-six-unit.toml"))
rows = Dict{String,Any}[]
for name in ("all_four", "without_hSelf", "without_hSMC", "without_hAct", "without_hBound")
    source = name == "without_hBound" ? four : six
    selection = name == "without_hBound" ? name : name * "_active_boundary"
    row = only(filter(w -> w["name"] == selection, source["witnesses"]))
    push!(rows, Dict("name" => name, "expected" => row["actual"], "source_domain" => source["domain"],
        "source_case_id" => row["case_id"], "circuit" => row["circuit"]))
end
path = joinpath(base, "..", "..", "..", "tools", "model_audit", "fixtures", "measured-witnesses.toml")
mkpath(dirname(path))
isfile(path) && error("refusing to replace an existing witness corpus")
open(io -> TOML.print(io, Dict("schema_version" => 1, "phenomenal_claim" => "not_certified", "witnesses" => rows); sorted=true), path, "w")
println("PASS froze five measured patterns from recorded exploratory searches")
