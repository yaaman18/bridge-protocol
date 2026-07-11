@testset "three-layer composition" begin
    states = [:a, :b, :c]
    step = (source, target) ->
        (source == :a && target == :b) || (source == :b && target == :b)
    live = check_layer_composition(states, step, state -> state in (:a, :b))
    @test live.viable_nonempty
    @test live.hinge_nonempty
    @test live.world_nontrivial
    @test live.endpoint_equivalent
    @test live.composition_commutes
    @test live.hilbert_loop == ones(1, 1)

    empty = check_layer_composition(states, step, _ -> false)
    @test !empty.viable_nonempty
    @test !empty.hinge_nonempty
    @test !empty.world_nontrivial
    @test empty.endpoint_equivalent
    @test empty.composition_commutes
    @test empty.hilbert_loop == zeros(1, 1)

    obstruction = layer_composition_nonfaithful_witness()
    @test obstruction.automorphisms_distinct
    @test obstruction.identity_image == obstruction.toggle_image
    @test obstruction.images_equal
    @test !obstruction.faithful
    @test !obstruction.hom_left_inverse_possible
end
