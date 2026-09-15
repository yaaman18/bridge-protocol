using Test
include(joinpath(@__DIR__, "mutation", "tools", "ModelAudit.jl"))
@testset failfast=true "DC predicates match direct quantifiers on all tiny encodings" begin
    # Enumerate all alpha/sigma/pi/rho relations and supports on this fixed carrier.
    # No ERIEC operators or checker results are used to obtain the reference values.
    C = (:e, :m, :c)
    complete_graph = Dict(c => Set(d for d in C if d != c) for c in C)
    chain_graph = Dict(:e => Set([:m]), :m => Set([:c]), :c => Set{Symbol}())
    observed_patterns = Set{NTuple{4,Bool}}()
    boundary_differs_from_proper_support = zeros(Int, 2)
    for (graph_index, neighbors) in enumerate((complete_graph, chain_graph)), bits in 0:4095
        bit(i) = !iszero(bits & (1 << i))
        model = (M=(:m,), E=(:e,), C=C,
            alpha=Dict(:m => Set{Symbol}(bit(0) ? (:e,) : ())),
            sigma=Dict(:e => Set{Symbol}(bit(1) ? (:m,) : ())),
            pi=Dict(:m => Set(C[i] for i in 1:3 if bit(i+1))),
            rho=Dict(C[i] => Set{Symbol}(bit(i+4) ? (:m,) : ()) for i in 1:3),
            kappa=Set(C[i] for i in 1:3 if bit(i+7)),
            epsilon=Set{Symbol}(bit(11) ? (:e,) : ()),
            neighbors=neighbors)
        K, I = model.kappa, model.epsilon
        produced(c) = any(c in model.pi[m] && any(m in model.rho[d] for d in K) for m in model.M)
        returned(e) = any(e in model.alpha[m] && any(m in model.sigma[d] for d in I) for m in model.M)
        active(m) = any(m in model.rho[d] for d in K) && any(m in model.sigma[e] for e in I)
        reference = (all(produced, K), all(returned, I), any(active, model.M),
            any(any(d ∉ K for d in model.neighbors[c]) for c in K))
        result = ModelAudit.check_dc_pattern(model, reference)
        @test result.valid && result.actual == reference
        @test result.act == Set(m for m in model.M if active(m))
        @test result.matches == (!isempty(K) && K != Set(C) && !isempty(I))
        push!(observed_patterns, reference)
        boundary_differs_from_proper_support[graph_index] += Int(reference[4] != (!isempty(K) && K != Set(C)))
    end
    # Every component was observed both true and false; this is not a general independence claim.
    @test all(Set(p[i] for p in observed_patterns) == Set((false, true)) for i in 1:4)
    @test boundary_differs_from_proper_support[1] == 0
    @test boundary_differs_from_proper_support[2] > 0
end

