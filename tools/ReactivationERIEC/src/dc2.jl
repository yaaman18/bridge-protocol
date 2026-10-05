# DC2 (formal-experiments/M1Refinement.lean, unratified) on a case record (RSB-003 §3.4).
# The checker is dc2_core.jl, the same file the finite-model audit includes.

const DC2_VALUE_KEYS = ["dc2", "hSelf2", "hSMC", "hHingeNeeded", "hUnit", "beta_nonempty"]
const DC2_DIAGNOSTIC_KEYS = ["act", "beta", "sigma_cover", "mutual_pairs", "hUnit_v1", "irreducible_units"]

"""DC2 with hUnit = MutualPair. `hUnit_v1` (IrredUnit ∧ NonSingleton) is a diagnostic only."""
struct DC2Criterion <: RM.AbstractCriterion end
RM.criterion_id(::DC2Criterion) = "dc2"
RM.criterion_version(::DC2Criterion) = "dc2-m1r-n3-rsb003-v1"
RM.required_structure(::DC2Criterion) = (:n, :inputs, :outputs)

function RM.evaluate(::DC2Criterion, record, structure)
    d = check_dc2(erie_model(record, structure))
    d.valid || throw(ArgumentError("the case record does not encode a DC2 model"))
    Dict("values" => Dict("dc2" => d.dc2, "hSelf2" => d.hSelf2, "hSMC" => d.hSMC,
                          "hHingeNeeded" => d.hHingeNeeded, "hUnit" => d.hUnit,
                          "beta_nonempty" => d.beta_nonempty),
         "diagnostics" => Dict(
             "act" => _names(d.act), "beta" => _names(d.beta), "sigma_cover" => d.sigma_cover,
             "mutual_pairs" => [_names(p) for p in d.mutual_pairs],
             "hUnit_v1" => d.hUnit_v1, "irreducible_units" => [_names(u) for u in d.irreducible_units]))
end
