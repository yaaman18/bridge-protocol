#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__, "..", "tools", "ImplicationMatrixAudit.jl"))

try
    ARGS == ["matrix"] ||
        throw(ArgumentError("Usage: eriec-implication-matrix-audit.jl matrix"))
    TOML.print(stdout, ImplicationMatrixAudit.implication_matrix_report(); sorted=true)
catch err
    println(stderr, "Implication matrix audit failed: ", sprint(showerror, err))
    exit(1)
end
