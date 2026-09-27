#!/usr/bin/env julia
# RSB-001 §8(5): launcher only. The registry runs in its own minimal project with a stdlib-only
# load path, so this entry point never loads ERIEC.

const PROJECT = normpath(joinpath(@__DIR__, "..", "tools", "SubstrateRegistry"))

cmd = addenv(`$(Base.julia_cmd()) --startup-file=no --project=$PROJECT
    -e "using SubstrateRegistry; exit(SubstrateRegistry.main(ARGS))" $ARGS`,
    "JULIA_LOAD_PATH" => "@:@stdlib")
exit(run(ignorestatus(cmd)).exitcode)
