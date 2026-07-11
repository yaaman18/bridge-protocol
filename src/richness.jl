"""Finite executable checks for hinge-branch richness obligations."""

function _rich_relation_lookup(rel, key)
    if rel isa AbstractDict
        return get(rel, key, Set())
    end
    rel(key)
end

"""Return true when `alpha_rel(m)` contains two distinct environment points."""
function is_branch_point(alpha_rel=Dict(:m0 => Set([:e0, :e1])), m=:m0)
    image = Set(_rich_relation_lookup(alpha_rel, m))
    any(left != right for left in image for right in image)
end

function _rich_union_image(rel, keys)
    out = Set()
    for key in keys
        union!(out, _rich_relation_lookup(rel, key))
    end
    out
end

"""Finite checker for the hinge-branch pump obligation.

The checker recomputes `Act`, verifies the SMC post-fixed premise on `epsilon`,
computes the finite greatest fixed point of `T_prime`, and checks every branch
point in `Act` has its alpha image inside that greatest fixed point.
"""
function check_hinge_branch_pump(;
    motors=(:m0,),
    environments=(:e0, :e1),
    cores=(:c0,),
    alpha_rel=Dict(:m0 => Set([:e0, :e1])),
    sigma_rel=Dict(:e0 => Set([:m0]), :e1 => Set([:m0])),
    rho_rel=Dict(:c0 => Set([:m0])),
    kappa=Set([:c0]),
    epsilon=Set([:e0, :e1]),
)
    motor_set = Set(motors)
    environment_set = Set(environments)
    core_set = Set(cores)

    all(c -> c in core_set, kappa) || return false
    all(e -> e in environment_set, epsilon) || return false
    all(m -> _rich_relation_lookup(alpha_rel, m) ⊆ environment_set, motors) || return false
    all(e -> _rich_relation_lookup(sigma_rel, e) ⊆ motor_set, environments) || return false
    all(c -> _rich_relation_lookup(rho_rel, c) ⊆ motor_set, cores) || return false

    sigma_star(x) = _rich_union_image(sigma_rel, x)
    alpha_star(x) = _rich_union_image(alpha_rel, x)
    t_prime(x) = alpha_star(sigma_star(x))

    act = intersect(_rich_union_image(rho_rel, kappa), sigma_star(epsilon))
    hsmc = epsilon ⊆ t_prime(epsilon)
    hsmc || return false

    nu = Set(environments)
    for _ in 1:(length(environments) + 2)
        next = intersect(t_prime(nu), environment_set)
        next == nu && break
        nu = next
    end

    all(motors) do motor
        !((motor in act) && is_branch_point(alpha_rel, motor)) ||
            (_rich_relation_lookup(alpha_rel, motor) ⊆ nu)
    end
end
