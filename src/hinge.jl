function T_prime(alpha_rel, sigma_rel, X)
    alpha_star(alpha_rel, sigma_star(sigma_rel, X))
end

function Act(rho_rel, sigma_rel, kappa::Function, epsilon::Function, s)
    rho_star(rho_rel, kappa(s)) ∩ sigma_star(sigma_rel, epsilon(s))
end

function check_hinge(rho_rel, sigma_rel, kappa::Function, epsilon::Function, s)
    !isempty(Act(rho_rel, sigma_rel, kappa, epsilon, s))
end

struct HingeIntegrityResult{M}
    self_maintaining::Set{M}
    sensory_supported::Set{M}
    act::Set{M}
    sensory_only::Set{M}
    self_only::Set{M}
    accepted::Bool
end

function hinge_integrity(
    rho_rel,
    sigma_rel,
    kappa::Function,
    epsilon::Function,
    s,
)
    self_maintaining = rho_star(rho_rel, kappa(s))
    sensory_supported = sigma_star(sigma_rel, epsilon(s))
    act = intersect(self_maintaining, sensory_supported)
    sensory_only = setdiff(sensory_supported, self_maintaining)
    self_only = setdiff(self_maintaining, sensory_supported)
    HingeIntegrityResult(
        self_maintaining,
        sensory_supported,
        act,
        sensory_only,
        self_only,
        !isempty(act) && isempty(sensory_only),
    )
end

function check_K2(sys)
    result = check_DC(sys)
    if !result.hAct
        @warn "K2 check failed: Act = ∅"
    end
    result.hAct
end

function check_K2_strict(sys)
    result = hinge_integrity(
        sys.structure.rho_rel,
        sys.structure.sigma_rel,
        sys.kappa,
        sys.epsilon,
        sys.s,
    )
    if !result.accepted
        @warn "K2 strict check failed" act=result.act sensory_only=result.sensory_only
    end
    result.accepted
end
