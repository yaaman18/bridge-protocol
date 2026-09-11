#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__,"..","tools","CountermodelAudit.jl"))
try
    if ARGS == ["catalog"]
        TOML.print(stdout,CountermodelAudit.finite_model_catalog();sorted=true)
    elseif length(ARGS)==2 && ARGS[1]=="query"
        query=CountermodelAudit.parse_countermodel_query(TOML.parsefile(ARGS[2]))
        TOML.print(stdout,CountermodelAudit.countermodel_query_report(
            CountermodelAudit.query_countermodels(query));sorted=true)
    else
        throw(ArgumentError("Usage: eriec-countermodel-audit.jl catalog | query QUERY.toml"))
    end
catch err
    println(stderr,"Countermodel audit failed: ",sprint(showerror,err))
    exit(1)
end
