function pi_star(pi_rel, A)
    _image_union(pi_rel, A)
end

function rho_star(rho_rel, Y)
    _image_union(rho_rel, Y)
end

function Phi(pi_rel, rho_rel, Y)
    pi_star(pi_rel, rho_star(rho_rel, Y))
end

struct NuPhiResult{C}
    value::Set{C}
    converged::Bool
    iterations::Int
end

function nu_phi(pi_rel, rho_rel, all_C; max_iter::Int=1000)
    Y = Set(all_C)
    for i in 1:max_iter
        phi_y = Phi(pi_rel, rho_rel, Y)
        y_new = Y ∩ phi_y
        y_new == Y && return NuPhiResult(y_new, true, i)
        Y = y_new
    end
    NuPhiResult(Y, false, max_iter)
end

function check_nu_phi_fixedpoint(pi_rel, rho_rel, result::NuPhiResult)
    Phi(pi_rel, rho_rel, result.value) == result.value
end

function check_final_coalgebra(pi_rel, rho_rel, result::NuPhiResult, all_C)
    check_nu_phi_fixedpoint(pi_rel, rho_rel, result) || return false
    all(powerset(Set(all_C))) do candidate
        image = Phi(pi_rel, rho_rel, candidate)
        !(candidate ⊆ image) || candidate ⊆ result.value
    end
end
