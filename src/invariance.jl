"""Finite executable check of `map ∘ update = update′ ∘ map`."""
function check_update_bisimulation(map_state, update, update_prime, samples)
    all(sample -> isequal(map_state(update(sample)), update_prime(map_state(sample))), samples)
end
