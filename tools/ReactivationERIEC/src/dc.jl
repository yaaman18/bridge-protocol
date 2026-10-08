# DC (ERIEC.check_DC) on a case record (RSB-003 §3.3, RSB-PLAN-002 §4.3 and §5.2).

const DC_VALUE_KEYS = ["dc", "hSelf", "hSMC", "hAct", "hBound"]
const DC_DIAGNOSTIC_KEYS = ["act", "boundary", "kappa_nonempty", "epsilon_nonempty",
                            "mask_self", "mask_smc", "mask_act", "hSelf_T"]

"""ERIEC's DC with the profile's boundary rule `outgoing_nonzero_edges`."""
struct DCCriterion <: RM.AbstractCriterion end
RM.criterion_id(::DCCriterion) = "dc"
RM.criterion_version(::DCCriterion) = "dc-rsb003-v2"
RM.required_structure(::DCCriterion) = (:n, :inputs, :outputs, :out_adjacency)

"""Core units with an out-neighbour (through a nonzero influence) outside the core, as a mask."""
graph_boundary(kappa::Integer, adjacency, n::Integer) =
    foldl((acc, i) -> (kappa >> i) & 1 == 1 && adjacency[i + 1] & ~kappa != 0 ? acc | (1 << i) : acc,
          0:(n - 1); init=0)

# Units whose final state changes under some silencing set but under no single-unit silencing.
function _collective_only_change(final::AbstractVector, n::Integer)
    length(final) == 1 << n || throw(ArgumentError("future_final must cover every silencing set"))
    single = 0
    any_change = 0
    for a in 1:((1 << n) - 1)
        changed = final[a + 1] ⊻ final[1]
        any_change |= changed
        count_ones(a) == 1 && (single |= changed)
    end
    any_change & ~single
end

"""
    hself_t(record, structure, model) -> Bool

Diagnostic hSelf_T (user decision 2026-10-07, logs/gates/DC-SEMANTICS-20261006/): every core
constituent is produced through the actions (c ∈ Φ(κ), the reading hSelf uses), or it is lost only
under joint silencing and every inclusion-minimal loss set of it meets κ ∪ ε. It credits redundantly
supported constituents only; it is not a certification of DC (design-r2: loss sets are not support
sets, and this diagnostic is not an alternative proof).
"""
function hself_t(record, structure, m)
    n = structure[:n]
    keep = record["kappa"] | (record["epsilon"] & structure[:inputs])
    phi = _dc2_phi(m.pi, m.rho, m.kappa)
    collective = record["collective_only_loss"]
    all(m.kappa) do c
        c in phi && return true
        i = parse(Int, String(c)[2:end])
        sets = record["loss_sets"][i + 1]
        (collective >> i) & 1 == 1 && !isempty(sets) && all(a -> a & keep != 0, sets)
    end
end

function RM.evaluate(::DCCriterion, record, structure)
    n = structure[:n]
    I, O = structure[:inputs], structure[:outputs]
    m = erie_model(record, structure)
    bmask = graph_boundary(record["kappa"], structure[:out_adjacency], n)
    sys = ERIEC.ERIEState{Symbol,Symbol,Symbol,Nothing}(
        a -> copy(m.alpha[a]), e -> copy(m.sigma[e]), a -> copy(m.pi[a]), c -> copy(m.rho[c]),
        _ -> copy(m.kappa), _ -> copy(m.epsilon), _units(bmask, n), nothing)
    r = ERIEC.check_DC(sys)
    loss = record["collective_only_loss"]
    change = _collective_only_change(record["future_final"], n)
    Dict("values" => Dict("dc" => ERIEC.is_DC(r), "hSelf" => r.hSelf, "hSMC" => r.hSMC,
                          "hAct" => r.hAct, "hBound" => r.hBound),
         "diagnostics" => Dict(
             "act" => _names(r.act), "boundary" => _names(_units(bmask, n)),
             "kappa_nonempty" => !isempty(m.kappa), "epsilon_nonempty" => !isempty(m.epsilon),
             # RSB-PLAN-002 §5.2: where each condition can be hidden by redundancy (an
             # over-estimate of "may be hidden", not a proof that it is).
             "mask_self" => _names(_units((loss & record["kappa"]) | (loss & O), n)),
             "mask_smc" => _names(_units(change & (I | O), n)),
             "mask_act" => _names(_units((loss & O) | (change & O), n)),
             "hSelf_T" => hself_t(record, structure, m)))
end
