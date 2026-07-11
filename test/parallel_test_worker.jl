using Test
using ERIEC

isempty(ARGS) && error("parallel test worker received no test files")

for file in ARGS
    include(joinpath(@__DIR__, file))
end
