# Revision 2 on the random circuits of sweep-and-search.jl (seed 20261009, 20,000 circuits): counts of
# the adopted criteria, and, for each mutant named on the command line (as in mutation.jl), the counts
# under that mutant, so that a mutant the frozen templates do not detect can be seen to matter or not.
root = joinpath(@__DIR__, "..", "..", "..", "tools", "AgencySubstrate")
using AgencySubstrate
const AS = AgencySubstrate
mut = get(ARGS, 1, "adopted")
edits = Dict(
    "tracking-any-change" => ["!= base[i], 1:2) == 1]" => "!= base[i], 1:2) >= 1]"],
    "repair-without-alive-check" => ["all(x -> any(v -> x.active[v] && !is_sensor(s, v), 1:nunits(s)), tail) || return false" => ""],
    "repair-without-constituent-requirement" => ["    any_constituent\nend" => "    true\nend"],
)
if mut != "adopted"
    m = read(joinpath(root, "src", "criteria.jl"), String)
    for (old, new) in edits[mut]
        count(old, m) == 1 || error("edit target not unique")
        global m = replace(m, old => new)
    end
    Base.include_string(AS, m)
end
include(joinpath(@__DIR__, "sweep-and-search-generator.jl"))
base = load_templates()
state = Ref(UInt64(20261009))
n = Dict(k => 0 for k in (:agency, :self_producing, :self_repairing, :agency_and_repairing, :core))
for k in 1:20000
    r = Base.invokelatest(evaluate, random_substrate(state), base)
    r.agency && (n[:agency] += 1); r.self_producing && (n[:self_producing] += 1)
    r.self_repairing && (n[:self_repairing] += 1); (r.agency && r.self_repairing) && (n[:agency_and_repairing] += 1)
    isempty(r.core) || (n[:core] += 1)
end
println(rpad(mut, 40), "agency=", n[:agency], " self_producing=", n[:self_producing], " self_repairing=", n[:self_repairing],
        " agency&repairing=", n[:agency_and_repairing], " core nonempty=", n[:core])
