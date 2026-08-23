#!/usr/bin/env julia

using ERIEC

exit(ERIEC.model_evaluation_cli(
    ARGS;
    project_root=normpath(joinpath(@__DIR__, "..")),
))
