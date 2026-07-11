@testset "update bisimulation" begin
    map_state(x) = 2x
    update(x) = x + 1
    update_prime(x) = x + 2

    @test check_update_bisimulation(map_state, update, update_prime, 0:10)
    @test !check_update_bisimulation(identity, update, update_prime, 0:10)
end
