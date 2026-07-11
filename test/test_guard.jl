@testset "terminal and mutation guards" begin
    objects = [:a, :b]
    no_terminal = (source, target) -> source == target
    terminal = (_, target) -> target == :b

    @test check_terminal_guard(objects, no_terminal)
    @test !check_terminal_guard(objects, terminal)
    @test check_trace_safe(first, pair -> (pair[1], pair[2] + 1), [(1, 0), (2, 3)])
    @test !check_trace_safe(last, pair -> (pair[1], pair[2] + 1), [(1, 0), (2, 3)])
end
