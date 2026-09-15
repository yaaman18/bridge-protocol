"""Enumerate exactly the role/weight/threshold-preserving automorphisms.
Initial-state preservation is an explicit context choice; names themselves are not fixed."""
function circuit_automorphisms(c::AuditCircuit; include_initial::Bool=true)
    n = length(c.units)
    n <= 8 || throw(ArgumentError("complete symmetry enumeration is limited to 8 units"))
    weights = zeros(Int64, n, n)
    for (s, d, w) in c.edges
        weights[s, d] = w
    end
    roles = Tuple(u in c.inputs ? :input : u in c.motors ? :motor : :internal for u in c.units)
    choices = [[j for j in 1:n if roles[i] == roles[j] && c.thresholds[i] == c.thresholds[j] &&
        (!include_initial || c.initial[i] == c.initial[j])] for i in 1:n]
    permutations = Tuple{Vararg{Int}}[]
    partial = zeros(Int, n)
    used = falses(n)
    function visit(i)
        if i > n
            push!(permutations, Tuple(partial))
            return
        end
        for j in choices[i]
            used[j] && continue
            # Previously assigned vertices suffice for incremental adjacency checking.
            all(k -> weights[i,k] == weights[j,partial[k]] && weights[k,i] == weights[partial[k],j], 1:(i-1)) || continue
            partial[i] = j
            used[j] = true
            visit(i+1)
            used[j] = false
        end
    end
    visit(1)
    Tuple(permutations)
end

function _permuted_support(mask::Int, permutation)
    result = 0
    for i in eachindex(permutation)
        iszero(mask & (1 << (i-1))) || (result |= 1 << (permutation[i]-1))
    end
    result
end

function audit_candidate_supports(c::AuditCircuit, supports; include_initial::Bool=true)
    n = length(c.units)
    masks = Int[]
    for support in supports
        names = _audit_strings(String.(collect(support)))
        !isempty(names) && Set(Symbol.(names)) ⊆ Set(c.units) || throw(ArgumentError("invalid candidate support"))
        mask = sum(1 << (findfirst(==(Symbol(name)), c.units)-1) for name in names)
        mask != (1 << n)-1 || throw(ArgumentError("candidate support must be proper"))
        mask ∉ masks || throw(ArgumentError("duplicate candidate support"))
        push!(masks, mask)
    end
    isempty(masks) && throw(ArgumentError("candidate class is empty"))
    automorphisms = circuit_automorphisms(c; include_initial)
    all(_permuted_support(mask, p) in masks for mask in masks for p in automorphisms) ||
        throw(ArgumentError("candidate class is not closed under the circuit symmetries"))
    fixed = Tuple(mask for mask in masks if all(_permuted_support(mask, p) == mask for p in automorphisms))
    classification = isempty(fixed) ? :obstructed_by_symmetry : length(fixed) == 1 ?
        :one_symmetry_compatible_candidate : :multiple_symmetry_compatible_candidates
    orbits = Tuple(Tuple(sort!(unique([_permuted_support(mask, p) for p in automorphisms]))) for mask in masks)
    (; circuit=c, include_initial, masks=Tuple(masks), automorphisms, fixed, orbits, classification,
       candidate_class_externally_supplied=true, intrinsic_decomposition_certified=false,
       phenomenal_claim=:not_certified)
end

function symmetry_audit_report(audit)
    c = audit.circuit
    support(mask) = [String(c.units[i]) for i in eachindex(c.units) if !iszero(mask & (1 << (i-1)))]
    Dict("schema_version" => 1, "circuit" => circuit_dict(c),
        "context" => audit.include_initial ? "dynamics_roles_and_initial_state" : "dynamics_and_roles",
        "include_initial" => audit.include_initial,
        "candidate_class_externally_supplied" => true, "candidate_class_closed" => true,
        "candidates" => support.(collect(audit.masks)), "fixed_candidates" => support.(collect(audit.fixed)),
        "candidate_orbit_masks" => collect.(collect(audit.orbits)),
        "automorphisms_one_based" => collect.(collect(audit.automorphisms)),
        "automorphism_count" => length(audit.automorphisms), "classification" => String(audit.classification),
        "intrinsic_decomposition_certified" => false, "phenomenal_claim" => "not_certified",
        "execution_certified" => false)
end
