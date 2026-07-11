copair(left, right, input::Pair) =
    first(input) === :left ? left(last(input)) : right(last(input))

function check_copair_unique(left, right, candidate, left_values, right_values)
    all(value -> candidate(:left => value) == left(value), left_values) &&
        all(value -> candidate(:right => value) == right(value), right_values) &&
        all(value -> candidate(:left => value) == copair(left, right, :left => value), left_values) &&
        all(value -> candidate(:right => value) == copair(left, right, :right => value), right_values)
end
