using LinearAlgebra
using ForwardDiff

sensitivity_tensor(sigma, a) = ForwardDiff.jacobian(sigma, a)

function sensitivity_tensor_adjoint(sigma, a)
    transpose(sensitivity_tensor(sigma, a))
end

function check_dual_symmetry(sigma, a, x, y; tol=1e-10)
    tensor = sensitivity_tensor(sigma, a)
    adjoint_tensor = transpose(tensor)
    abs(dot(tensor * x, y) - dot(x, adjoint_tensor * y)) < tol
end

function check_adjoint_unit_counterexample(tensor::AbstractMatrix)
    size(tensor, 1) == size(tensor, 2) ||
        throw(ArgumentError("tensor must be square"))
    dimension = size(tensor, 2)
    any(1:dimension) do index
        basis = zeros(eltype(tensor), dimension)
        basis[index] = one(eltype(tensor))
        norm(adjoint(tensor) * (tensor * basis)) < norm(basis)
    end
end
