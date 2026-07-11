function viability_contribution(nu_phi::Set, contribution::Function, e)
    length(intersect(contribution(e), nu_phi))
end

struct Measure{F}
    mu::F
end

cardinality_measure() = Measure(length)

function viability_weight_ratio(
    nu_phi::Set,
    contribution::Function,
    e;
    measure::Measure=cardinality_measure(),
)
    denominator = measure.mu(nu_phi)
    denominator == 0 && throw(ArgumentError("measure(nu_phi) must be nonzero"))
    measure.mu(intersect(contribution(e), nu_phi)) / denominator
end

function check_value_endogenous(nu_phi::Set, contribution::Function, e)
    isempty(nu_phi) && return false
    value = viability_weight_ratio(nu_phi, contribution, e)
    0 <= value <= 1 && value == viability_weight_ratio(copy(nu_phi), contribution, e)
end

function relational_normalized_value(all_C, sigma_rel, pi_rel, rho_rel, e)
    core = nu_phi(pi_rel, rho_rel, all_C)
    core.converged || throw(ArgumentError("nu_phi computation must converge"))
    contribution = channel -> pi_star(pi_rel, sigma_rel(channel))
    viability_weight_ratio(core.value, contribution, e)
end

function check_value_endogenous(
    all_C,
    sigma1,
    pi1,
    rho1,
    sigma2,
    pi2,
    rho2,
    e,
)
    sigma1 === sigma2 || return false
    pi1 === pi2 || return false
    rho1 === rho2 || return false
    relational_normalized_value(all_C, sigma1, pi1, rho1, e) ==
        relational_normalized_value(all_C, sigma2, pi2, rho2, e)
end

function has_structural_weight(nu_phi::Set, contribution::Function, e)
    viability_contribution(nu_phi, contribution, e) > 0
end

struct MatteringBridge
    to_mattering::Function
end

function mattering_of_bridge(bridge::MatteringBridge, nu_phi::Set, contribution::Function, e)
    @assert has_structural_weight(nu_phi, contribution, e)
    bridge.to_mattering(e)
end

function value_countermodel()
    (
        nu_phi=Set([()]),
        contribution=_ -> Set([()]),
        mattering=_ -> false,
    )
end

struct StableValueCountermodel
    ranks::Tuple{Bool,Bool}
    relation::Function
    omega::Bool
    kappa::Set
    epsilon::Set
    boundary::Set
    nu_phi::Set
    contribution::Function
    external_predicate::Function
end

function stable_value_countermodel()
    relation = (rank, _) -> rank ? Set() : Set([()])
    StableValueCountermodel(
        (false, true),
        relation,
        false,
        Set([()]),
        Set([()]),
        Set([()]),
        Set([()]),
        _ -> Set([()]),
        _ -> false,
    )
end

function check_value_countermodel(model::StableValueCountermodel)
    low, high = model.ranks
    low == false && high == true || return false
    isempty(model.relation(high, ())) || return false
    model.relation(low, ()) == Set([()]) || return false
    !isempty(intersect(model.kappa, model.boundary)) || return false
    model.kappa == model.nu_phi || return false
    contribution = model.contribution(())
    has_structural_weight(model.nu_phi, _ -> contribution, ()) || return false
    !model.external_predicate(())
end
