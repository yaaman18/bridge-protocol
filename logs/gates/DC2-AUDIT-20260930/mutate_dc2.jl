using ERIEC
include("/Users/yamaguchimitsuyuki/bridge-protocol/tools/ModelAudit.jl")
# direct_dc2 from the test file, without running the testsets
src = read("/Users/yamaguchimitsuyuki/bridge-protocol/test/test_dc2_audit.jl", String)
fstart = findfirst("function direct_dc2", src).start
fend = findfirst("\nend\n", src[fstart:end]).stop + fstart - 1
eval(Meta.parse(src[fstart:fend]))
# check_dc2 moved to tools/ReactivationERIEC/src/dc2_core.jl by RSB-003 (2026-10-04)
orig = read("/Users/yamaguchimitsuyuki/bridge-protocol/tools/ReactivationERIEC/src/dc2_core.jl", String)
cstart = findfirst("function check_dc2", orig).start
cend = findfirst("\nend\n", orig[cstart:end]).stop + cstart - 1
body = orig[cstart:cend]
mutations = [
  "hinge not removed" => ("_dc2_postfixed(C, model.pi, rhoNH," => "_dc2_postfixed(C, model.pi, model.rho,"),
  "Psi dropped" => ("post = [_dc2_postfixed(C, model.pi, model.rho, _dc2_subset(items, v))" => "post = [_dc2_subset(items, v) ⊆ _dc2_phi(model.pi, model.rho, _dc2_subset(items, v))"),
  "beta via rho*" => ("beta = intersect(K, _dc2_star(model.pi, act))" => "beta = intersect(K, _dc2_phi(model.pi, model.rho, K))"),
  "hSMC ignores sigma" => ("_dc2_star(model.alpha, _dc2_star(model.sigma, eps))" => "_dc2_star(model.alpha, collect(model.M))"),
  "hUnit_v1 proper subset check skipped" => ("proper_post && continue" => "false && continue"),
  "MutualPair one direction only" => ("if c in produced[d] && d in produced[c]]" => "if c in produced[d]]"),
  "MutualPair allows c == d" => ("for (i, c) in enumerate(items) for d in items[(i + 1):end]" => "for (i, c) in enumerate(items) for d in items[i:end]"),
]
for (label, (a, b)) in mutations
    occursin(a, body) || (println(label, ": PATTERN NOT FOUND"); continue)
    Core.eval(ModelAudit, Meta.parse(replace(body, a => b)))
    hit = nothing
    for bits in 0:((1 << 20) - 1)
        m = ModelAudit.dc2_carrier_model(bits)
        d, r = ModelAudit.check_dc2(m), direct_dc2(m)
        if (d.hSelf2, d.hSMC, d.hHingeNeeded, d.hUnit, d.hUnit_v1) != (r.hSelf2, r.hSMC, r.hHingeNeeded, r.hUnit, r.hUnit_v1) || d.beta != r.beta
            hit = bits; break
        end
    end
    println(label, ": ", hit === nothing ? "NOT DETECTED" : "detected at encoding $hit")
    Core.eval(ModelAudit, Meta.parse(body))
end
