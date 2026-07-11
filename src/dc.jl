struct ERIEStructure{M,E,C}
    alpha_rel
    sigma_rel
    pi_rel
    rho_rel
    hGC::Union{Bool,Nothing}
end

function ERIEStructure{M,E,C}(
    alpha_rel,
    sigma_rel,
    pi_rel,
    rho_rel,
) where {M,E,C}
    ERIEStructure{M,E,C}(alpha_rel, sigma_rel, pi_rel, rho_rel, nothing)
end

function ERIEStructure{M,E,C}(
    alpha_rel,
    sigma_rel,
    pi_rel,
    rho_rel,
    all_M,
    all_E,
) where {M,E,C}
    hGC = check_galois_conn(alpha_rel, sigma_rel, all_M, powerset(all_E))
    hGC || throw(ArgumentError("alpha_rel and sigma_rel do not satisfy GaloisConnection"))
    ERIEStructure{M,E,C}(alpha_rel, sigma_rel, pi_rel, rho_rel, true)
end

function check_erie_structure(
    structure::ERIEStructure;
    all_M=nothing,
    all_E=nothing,
)
    structure.hGC === false && return false
    if all_M !== nothing || all_E !== nothing
        all_M !== nothing && all_E !== nothing ||
            throw(ArgumentError("all_M and all_E must be provided together"))
        return check_galois_conn(
            structure.alpha_rel,
            structure.sigma_rel,
            all_M,
            powerset(all_E),
        )
    end
    true
end

struct ERIEState{M,E,C,S}
    structure::ERIEStructure{M,E,C}
    kappa::Function
    epsilon::Function
    boundary::Set{C}
    s::S
end

function ERIEState{M,E,C,S}(
    alpha_rel,
    sigma_rel,
    pi_rel,
    rho_rel,
    kappa,
    epsilon,
    boundary,
    s,
) where {M,E,C,S}
    structure = ERIEStructure{M,E,C}(alpha_rel, sigma_rel, pi_rel, rho_rel)
    ERIEState{M,E,C,S}(structure, kappa, epsilon, boundary, s)
end

function ERIEState{M,E,C,S}(
    alpha_rel,
    sigma_rel,
    pi_rel,
    rho_rel,
    kappa,
    epsilon,
    boundary,
    s,
    all_M,
    all_E,
) where {M,E,C,S}
    structure = ERIEStructure{M,E,C}(alpha_rel, sigma_rel, pi_rel, rho_rel, all_M, all_E)
    ERIEState{M,E,C,S}(structure, kappa, epsilon, boundary, s)
end

struct DCResult
    hSelf::Bool
    hSMC::Bool
    hAct::Bool
    hBound::Bool
    act::Set
end

function check_DC(sys::ERIEState)
    structure = sys.structure
    kappa_s = sys.kappa(sys.s)
    epsilon_s = sys.epsilon(sys.s)
    act = Act(structure.rho_rel, structure.sigma_rel, sys.kappa, sys.epsilon, sys.s)

    h_self = kappa_s ⊆ Phi(structure.pi_rel, structure.rho_rel, kappa_s)
    h_smc = epsilon_s ⊆ T_prime(structure.alpha_rel, structure.sigma_rel, epsilon_s)
    h_act = !isempty(act)
    h_bound = !isempty(kappa_s ∩ sys.boundary)

    DCResult(h_self, h_smc, h_act, h_bound, act)
end

function is_DC(result::DCResult)
    result.hSelf && result.hSMC && result.hAct && result.hBound
end

function check_critical_bound(operator, threshold, rank, lt, configuration)
    isempty(configuration) || !(configuration ⊆ operator(rank, configuration)) ||
        !lt(threshold, rank)
end
