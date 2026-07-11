@testset "ranked relation presheaf" begin
    ranks = 0:2
    leq = <=
    antitone = (rank, left, right) -> left == right && rank <= 1
    non_antitone = (rank, left, right) -> left == right && rank >= 1

    @test check_const_presheaf_antitone(antitone, ranks, leq, 1:2, 1:2)
    @test !check_const_presheaf_antitone(non_antitone, ranks, leq, 1:2, 1:2)
end


@testset "critical rank collapse bound" begin
    ranks = 0:2
    carrier = Set([:c1, :c2])
    collapsing = (rank, candidate) -> rank <= 1 ? copy(candidate) : Set{Symbol}()
    noncollapsing = (_, candidate) -> copy(candidate)

    @test check_sig2_collapse_bound(collapsing, ranks, 1, <, carrier)
    @test !check_sig2_collapse_bound(noncollapsing, ranks, 1, <, carrier)
end
