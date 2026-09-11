using TOML
include(joinpath(@__DIR__, "..", "..", "..", "tools", "CountermodelAudit.jl"))

catalog = CountermodelAudit.finite_model_catalog()
open(joinpath(@__DIR__, "finite-model-catalog.toml"), "w") do io
    TOML.print(io, catalog; sorted=true)
end

for stem in ("dc-implies-max", "self-implies-smc", "one-input-active-boundary",
             "max-support-selects-component")
    query = CountermodelAudit.parse_countermodel_query(
        TOML.parsefile(joinpath(@__DIR__, "query-" * stem * ".toml")))
    report = CountermodelAudit.countermodel_query_report(
        CountermodelAudit.query_countermodels(query, catalog))
    open(joinpath(@__DIR__, "report-" * stem * ".toml"), "w") do io
        TOML.print(io, report; sorted=true)
    end
end
