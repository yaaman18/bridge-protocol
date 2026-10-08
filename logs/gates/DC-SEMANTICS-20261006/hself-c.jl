# hSelf (current, single silencing through motors) vs hSelf_C (κ ⊆ C_min(κ), C relativised to ε).
# Is C a targeted fix for redundancy, or a broad change of what hSelf means? Exploratory.
using ERIEC
include(joinpath(@__DIR__, "..", "..", "..", "tools", "ModelAudit.jl"))
const MA = ModelAudit
for (domain, limit) in ((:four_unit_exhaustive, nothing), (:six_unit_sequence, 6000))
    R = Dict{String,Int}()
    bump(k) = (R[k] = get(R, k, 0) + 1)
    MA.for_each_search_circuit(domain, limit, 20260910) do c, id
        units, n = c.units, length(c.units)
        m = MA.measure_circuit(c)
        kappa = m.model.kappa
        isempty(kappa) && return
        bump("cores")
        bit(u) = 1 << (findfirst(==(u), units) - 1)
        mask_of(Y) = foldl((acc, u) -> acc | bit(u), Y; init=0)
        keep = mask_of(kappa) | mask_of(m.model.epsilon)
        hC = all(u -> !isempty(m.minima[u]) && all(a -> a & keep != 0, m.minima[u]), kappa)
        hS = m.result.actual[1]
        motors = Set(c.motors)
        # redundancy explanation: the RSB-PLAN-002 §5.2 mask for hSelf
        mask_self = !isempty(intersect(m.collective, kappa)) || !isempty(intersect(m.collective, motors))
        motor_in_core = !isempty(intersect(kappa, motors))
        if hS && hC
            bump("both_true")
        elseif !hS && !hC
            bump("both_false")
        elseif hS && !hC
            bump("hSelf_only")                      # C stricter
        else
            bump("hSelfC_only")                     # C rescues
            mask_self ? bump("hSelfC_only:redundancy_masked") : bump("hSelfC_only:NOT_redundancy")
            motor_in_core || bump("hSelfC_only:no_motor_in_core")
        end
    end
    println("== ", domain)
    for k in sort!(collect(keys(R)))
        println("  ", rpad(k, 38), R[k])
    end
end
