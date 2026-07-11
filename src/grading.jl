"""Check antitonicity of a rank-indexed relation on finite carriers."""
function check_const_presheaf_antitone(relation, ranks, leq, left_carrier, right_carrier)
    all(
        !leq(low, high) || !relation(high, left, right) || relation(low, left, right)
        for low in ranks, high in ranks, left in left_carrier, right in right_carrier
    )
end

function check_sig2_collapse_bound(operator, ranks, threshold, lt, carrier)
    subsets = powerset(Set(carrier))
    all(ranks) do rank
        !lt(threshold, rank) || all(subsets) do candidate
            isempty(candidate) || !(candidate ⊆ operator(rank, candidate))
        end
    end
end
