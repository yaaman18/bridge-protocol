using LinearAlgebra

function weighted_sensitivity(tensor::AbstractMatrix, weights::AbstractVector)
    length(weights) == size(tensor, 2) ||
        throw(DimensionMismatch("weights length must match tensor column count"))
    tensor * Diagonal(weights)
end

function viability_weights(nu_phi::Set, contribution::Function, channels)
    [viability_contribution(nu_phi, contribution, channel) for channel in channels]
end
