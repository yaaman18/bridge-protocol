using LinearAlgebra

"""Incidence matrix of a finite relation, with codomain rows and domain columns."""
function relation_incidence_matrix(rel, domain, codomain)
    domain_items = collect(domain)
    codomain_items = collect(codomain)
    Float64[
        target in apply(rel, source) ? 1.0 : 0.0
        for target in codomain_items, source in domain_items
    ]
end

"""Check that finite converse relations linearize to transpose operators."""
function check_converse_adjoint(alpha_rel, sigma_rel, all_M, all_E)
    alpha_matrix = relation_incidence_matrix(alpha_rel, all_M, all_E)
    sigma_matrix = relation_incidence_matrix(sigma_rel, all_E, all_M)
    sigma_matrix == transpose(alpha_matrix)
end

"""Check that a concrete sensitivity Jacobian realizes a relation incidence matrix."""
function check_relation_sensitivity_bridge(alpha_rel, all_M, all_E, sigma, base)
    tensor = sensitivity_tensor(sigma, base)
    incidence = relation_incidence_matrix(alpha_rel, all_M, all_E)
    size(tensor) == size(incidence) && tensor == incidence
end

"""Check incidence-matrix naturality under finite carrier bijections."""
function check_relation_linearization_naturality(
    rel,
    rel_prime,
    domain,
    codomain,
    domain_prime,
    codomain_prime,
    map_domain,
    map_codomain,
)
    source_domain = collect(domain)
    source_codomain = collect(codomain)
    target_domain = collect(domain_prime)
    target_codomain = collect(codomain_prime)
    mapped_domain = map(map_domain, source_domain)
    mapped_codomain = map(map_codomain, source_codomain)

    length(unique(mapped_domain)) == length(source_domain) || return false
    length(unique(mapped_codomain)) == length(source_codomain) || return false
    Set(mapped_domain) == Set(target_domain) || return false
    Set(mapped_codomain) == Set(target_codomain) || return false
    all(
        (target in apply(rel, source)) ==
            (map_codomain(target) in apply(rel_prime, map_domain(source)))
        for source in source_domain, target in source_codomain
    ) || return false

    relation_incidence_matrix(rel, source_domain, source_codomain) ==
        relation_incidence_matrix(rel_prime, mapped_domain, mapped_codomain)
end

"""Check the entrywise lax inequality induced by a finite relation morphism."""
function check_relation_hom_lax_naturality(
    rel,
    rel_prime,
    domain,
    codomain,
    map_domain,
    map_codomain,
)
    all(
        !(target in apply(rel, source)) ||
            map_codomain(target) in apply(rel_prime, map_domain(source))
        for source in domain, target in codomain
    )
end

"""Witness that forward-only relation morphisms need not preserve matrices exactly."""
function strict_relation_hom_naturality_counterexample()
    rel = _ -> Set{Symbol}()
    rel_prime = _ -> Set([:target])
    map_domain = _ -> :mapped
    map_codomain = _ -> :target
    lax = check_relation_hom_lax_naturality(
        rel,
        rel_prime,
        [:source],
        [:edge],
        map_domain,
        map_codomain,
    )
    source = relation_incidence_matrix(rel, [:source], [:edge])
    target = relation_incidence_matrix(rel_prime, [:mapped], [:target])
    (lax=lax, strict=source == target, source=source, target=target)
end
