#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__,"..","tools","ClosureAudit.jl"))
try
    ARGS == ["examples"] || throw(ArgumentError("Usage: julia --project=. bin/eriec-closure-audit.jl examples"))
    TOML.print(stdout,ClosureAudit.closure_audit_report();sorted=true)
catch err
    println(stderr,"Closure audit failed: ",sprint(showerror,err))
    exit(1)
end
