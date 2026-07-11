function _image_union(rel, xs)
    out = Set{Any}()
    for x in xs
        union!(out, apply(rel, x))
    end
    out
end

function alpha_star(alpha_rel, N)
    _image_union(alpha_rel, N)
end

function sigma_star_induced(alpha_rel, all_M, X)
    Set(m for m in all_M if apply(alpha_rel, m) ⊆ X)
end

function sigma_star(sigma_rel, X)
    _image_union(sigma_rel, X)
end

function powerset(xs)
    items = collect(xs)
    n = length(items)
    result = Vector{Set{eltype(items)}}()
    sizehint!(result, 2^n)
    for mask in 0:(2^n - 1)
        subset = Set{eltype(items)}()
        for i in 1:n
            if (mask & (1 << (i - 1))) != 0
                push!(subset, items[i])
            end
        end
        push!(result, subset)
    end
    result
end

function check_K3(alpha_rel, sigma_rel, all_M, sample_E_subsets)
    check_K3(alpha_rel, all_M, sample_E_subsets)
end

function check_K3(alpha_rel, all_M, sample_E_subsets)
    for N in powerset(all_M), X in sample_E_subsets
        lhs = alpha_star(alpha_rel, N) ⊆ X
        rhs = N ⊆ sigma_star_induced(alpha_rel, all_M, X)
        @assert lhs == rhs "K3 check failed: N=$N, X=$X violates GaloisConnection"
    end
    true
end

function check_galois_conn(alpha_rel, sigma_rel, all_M, sample_E_subsets)
    for N in powerset(all_M), X in sample_E_subsets
        lhs = alpha_star(alpha_rel, N) ⊆ X
        rhs = N ⊆ sigma_star(sigma_rel, X)
        lhs == rhs || return false
    end
    true
end

"""Finite decision procedure for the rigidity conclusion of theorem 1.3."""
function check_relational_rigidity(alpha_rel, sigma_rel, all_M, all_E)
    subsets_E = powerset(all_E)
    check_galois_conn(alpha_rel, sigma_rel, all_M, subsets_E) || return false
    all(m -> length(apply(alpha_rel, m)) == 1, all_M) || return false
    all((m in apply(sigma_rel, e)) == (e in apply(alpha_rel, m))
        for m in all_M, e in all_E)
end
