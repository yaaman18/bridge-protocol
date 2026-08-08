"""Check the implemented viable -> relational -> hinge -> Hilbert composition."""
function check_layer_composition(states, step, viable)
    viability = check_viability_closure(states, step, viable)
    relational = check_viability_relational_frame(states, step, viable)
    hinge = intersect(relational.left_closure, relational.right_closure)
    hinge_nonempty = !isempty(hinge)
    viable_nonempty = !isempty(relational.viable_states)
    hilbert_loop = hinge_nonempty ? ones(1, 1) : zeros(1, 1)
    world_nontrivial = hilbert_loop[1, 1] == 1
    left_associated = hilbert_loop
    right_associated = hinge_nonempty ? ones(1, 1) : zeros(1, 1)
    endpoint_equivalent = world_nontrivial == viable_nonempty
    (
        viable_nonempty=viable_nonempty,
        hinge_nonempty=hinge_nonempty,
        world_nontrivial=world_nontrivial,
        endpoint_equivalent=endpoint_equivalent,
        composition_commutes=left_associated == right_associated,
        hilbert_loop=hilbert_loop,
        contract_premises=viability.step_closed,
        contract_conclusion=endpoint_equivalent,
        contract_holds=viability.step_closed && endpoint_equivalent,
    )
end

"""Finite witness that the composite forgets distinct viable automorphisms."""
function layer_composition_nonfaithful_witness()
    identity_automorphism = Dict(false => false, true => true)
    toggle_automorphism = Dict(false => true, true => false)
    hilbert_identity = ones(1, 1)
    (
        automorphisms_distinct=identity_automorphism != toggle_automorphism,
        identity_image=hilbert_identity,
        toggle_image=copy(hilbert_identity),
        images_equal=true,
        faithful=false,
        hom_left_inverse_possible=false,
    )
end
