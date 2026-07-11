@testset "consume" begin
    payload = (value=41,)
    consumer = Consumer(p -> p.value + 1)
    @test consume(consumer, payload) == 42

    failing = Consumer(_ -> throw(ArgumentError("boom")))
    @test_throws ArgumentError consume(failing, payload)

    alpha_rel = m -> m == :m1 ? Set([:e1]) : Set([:e2])
    sigma_rel = e -> e == :e1 ? Set([:m1]) : Set([:m2])
    all_M = Set([:m1, :m2])
    all_E = Set([:e1, :e2])
    calls = Ref(0)
    sink = Consumer(_ -> (calls[] += 1; nothing))

    @test check_consumer_preserves_k3(sink, payload, alpha_rel, sigma_rel, all_M, all_E)
    @test calls[] == 1
end
