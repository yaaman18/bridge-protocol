# Mutation checks for the RSB-003 DC criterion: each mutation must disagree with the independent
# mask implementation of the plugin test on some case.
using ReactivationMeasurement, ReactivationERIEC, ERIEC
const RM = ReactivationMeasurement; const RE = ReactivationERIEC
src = read(joinpath(@__DIR__, "..", "..", "..", "tools", "ReactivationERIEC", "test", "runtests.jl"), String)
for name in ("bits", "star", "case_and_structure", "judge", "random_substrate", "direct_dc")
    i = findfirst("\n" * (name == "bits" || name == "star" || name == "judge" ? name * "(" : "function " * name), src)
    i === nothing && error(name)
end
# Evaluate the helper definitions (everything before the first @testset).
eval(Meta.parseall(src[findfirst("bits(mask, n)", src).start:findfirst("# RSB-PLAN-002 §5.3", src).start - 1]))
function disagree()
    for k in 1:60, n in (4, 5), env in (false, true)
        sub = random_substrate(1000k + n, n; env)
        for q in 0:((1 << n) - 1)
            r, s = case_and_structure(sub, PROTO, q)
            judge(RE.DCCriterion(), r, s)["values"] == direct_dc(sub, r) || return true
        end
    end
    false
end
println("baseline disagrees: ", disagree())
# 1. boundary read along incoming edges
@eval RE graph_boundary(kappa::Integer, adjacency, n::Integer) =
    foldl((acc, i) -> (kappa >> i) & 1 == 1 && any(j -> (adjacency[j + 1] >> i) & 1 == 1 && (kappa >> j) & 1 == 0, 0:(n - 1)) ? acc | (1 << i) : acc, 0:(n - 1); init=0)
println("boundary along incoming edges detected: ", disagree())
@eval RE graph_boundary(kappa::Integer, adjacency, n::Integer) =
    foldl((acc, i) -> (kappa >> i) & 1 == 1 && adjacency[i + 1] & ~kappa != 0 ? acc | (1 << i) : acc, 0:(n - 1); init=0)
# 2. alpha not restricted to the inputs
@eval RE function erie_model(record::AbstractDict, structure)
    n = structure[:n]; I, O = structure[:inputs], structure[:outputs]
    outs, ins = _bits(O, n), _bits(I, n)
    (M=Tuple(_unit(i) for i in outs), E=Tuple(_unit(i) for i in ins), C=Tuple(_unit(i) for i in 0:(n - 1)),
     alpha=Dict(_unit(i) => _units(record["alpha"][i + 1], n) for i in outs),
     sigma=Dict(_unit(i) => _units(record["sigma"][i + 1] & O, n) for i in ins),
     pi=Dict(_unit(i) => _units(record["pi"][i + 1], n) for i in outs),
     rho=Dict(_unit(i) => _units(record["rho"][i + 1] & O, n) for i in 0:(n - 1)),
     kappa=_units(record["kappa"], n), epsilon=_units(record["epsilon"] & I, n))
end
println("alpha unrestricted detected: ", disagree())
# 3. sigma not restricted to the outputs
@eval RE function erie_model(record::AbstractDict, structure)
    n = structure[:n]; I, O = structure[:inputs], structure[:outputs]
    outs, ins = _bits(O, n), _bits(I, n)
    (M=Tuple(_unit(i) for i in outs), E=Tuple(_unit(i) for i in ins), C=Tuple(_unit(i) for i in 0:(n - 1)),
     alpha=Dict(_unit(i) => _units(record["alpha"][i + 1] & I, n) for i in outs),
     sigma=Dict(_unit(i) => _units(record["sigma"][i + 1], n) for i in ins),
     pi=Dict(_unit(i) => _units(record["pi"][i + 1], n) for i in outs),
     rho=Dict(_unit(i) => _units(record["rho"][i + 1] & O, n) for i in 0:(n - 1)),
     kappa=_units(record["kappa"], n), epsilon=_units(record["epsilon"] & I, n))
end
println("sigma unrestricted detected: ", disagree())
# Note: mutations 2 and 3 are equivalent mutants. rsb-case-record-v1 already restricts alpha to the
# inputs and sigma to the outputs (formats.jl), so the plugin's own restriction changes nothing.
# 4. a non-equivalent mutant on the hSMC side: epsilon read as empty (hSMC becomes vacuously true)
@eval RE function erie_model(record::AbstractDict, structure)
    n = structure[:n]; I, O = structure[:inputs], structure[:outputs]
    outs, ins = _bits(O, n), _bits(I, n)
    (M=Tuple(_unit(i) for i in outs), E=Tuple(_unit(i) for i in ins), C=Tuple(_unit(i) for i in 0:(n - 1)),
     alpha=Dict(_unit(i) => _units(record["alpha"][i + 1] & I, n) for i in outs),
     sigma=Dict(_unit(i) => _units(record["sigma"][i + 1] & O, n) for i in ins),
     pi=Dict(_unit(i) => _units(record["pi"][i + 1], n) for i in outs),
     rho=Dict(_unit(i) => _units(record["rho"][i + 1] & O, n) for i in 0:(n - 1)),
     kappa=_units(record["kappa"], n), epsilon=Set{Symbol}())
end
println("epsilon read as empty detected: ", disagree())
