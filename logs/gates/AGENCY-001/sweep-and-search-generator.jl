# The random circuit generator of sweep-and-search.jl, shared.
function random_substrate(rng_state)
    s = rng_state
    draw(k) = (s[] = s[] * 0x5851f42d4c957f2d + 0x14057b7ef767814f; Int((s[] >> 33) % UInt64(k)))
    names = ["s1", "s2", "m1", "m2", "x1", "x2", "x3"]
    n = length(names)
    edges = NTuple{3,Int}[]
    for src in 1:n, dst in 3:n          # sensors receive no edges
        src == dst && continue
        r = draw(6)
        r == 0 && push!(edges, (src, dst, -1))
        r in (1, 2) && push!(edges, (src, dst, 1))
    end
    theta = [1, 1, 1 + draw(2), 1 + draw(2), 1 + draw(2), 1 + draw(2), 1 + draw(2)]
    initial = [false, false, false, false, draw(2) == 0, draw(2) == 0, draw(2) == 0]
    AS.Substrate(names, theta, edges, Dict(3 => 1, 4 => 2), Dict(1 => 1, 2 => 2), Dict{Int,Tuple{Int,String}}(), true, initial)
end
