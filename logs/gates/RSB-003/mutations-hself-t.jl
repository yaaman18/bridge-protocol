# Mutation checks for the hSelf_T diagnostic (2026-10-07): each mutant must disagree with the
# independent implementation of the plugin test on some circuit of the four-unit audit domain.
using ReactivationMeasurement, ReactivationERIEC, ERIEC
const RM = ReactivationMeasurement; const RE = ReactivationERIEC
REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
include(joinpath(REPO, "tools", "ModelAudit.jl"))
src = read(joinpath(REPO, "tools", "ReactivationERIEC", "test", "runtests.jl"), String)
eval(Meta.parseall(src[findfirst("bits(mask, n)", src).start:findfirst("@testset \"RSB-003", src).start - 1]))
function disagree()
    hit = false
    ModelAudit.for_each_search_circuit(:four_unit_exhaustive, nothing, 20260910) do c, id
        hit && return
        n = length(c.units); idx(u) = findfirst(==(u), c.units) - 1
        sub = RM.Substrate(n, [(s - 1, t - 1, w) for (s, t, w) in c.edges], collect(c.thresholds),
            foldl((m, u) -> m | (1 << idx(u)), c.inputs; init=0), foldl((m, u) -> m | (1 << idx(u)), c.motors; init=0))
        q = foldl((m, i) -> c.initial[i] ? m | (1 << (i - 1)) : m, 1:n; init=0)
        r, s = case_and_structure(sub, RM.Protocol(c.P, c.L, c.H, c.R), q)
        judge(RE.DCCriterion(), r, s)["diagnostics"]["hSelf_T"] == direct_hself_t(sub, r) || (hit = true)
    end
    hit
end
println("baseline disagrees: ", disagree())
@eval RE function hself_t(record, structure, m)
    keep = record["kappa"] | (record["epsilon"] & structure[:inputs])
    phi = _dc2_phi(m.pi, m.rho, m.kappa)
    all(m.kappa) do c
        c in phi && return true
        i = parse(Int, String(c)[2:end]); sets = record["loss_sets"][i + 1]
        !isempty(sets) && all(a -> a & keep != 0, sets)          # collective-only condition dropped
    end
end
println("collective-only condition dropped detected: ", disagree())
@eval RE function hself_t(record, structure, m)
    keep = record["kappa"]                                         # ε relativisation dropped
    phi = _dc2_phi(m.pi, m.rho, m.kappa)
    collective = record["collective_only_loss"]
    all(m.kappa) do c
        c in phi && return true
        i = parse(Int, String(c)[2:end]); sets = record["loss_sets"][i + 1]
        (collective >> i) & 1 == 1 && !isempty(sets) && all(a -> a & keep != 0, sets)
    end
end
println("epsilon relativisation dropped detected: ", disagree())
