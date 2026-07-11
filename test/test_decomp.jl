@testset "copair uniqueness" begin
    left = value -> value + 1
    right = value -> value * 2
    candidate = tagged -> first(tagged) === :left ? left(last(tagged)) : right(last(tagged))
    invalid = tagged -> last(tagged)

    @test check_copair_unique(left, right, candidate, 1:3, 1:3)
    @test !check_copair_unique(left, right, invalid, 1:3, 1:3)
end
