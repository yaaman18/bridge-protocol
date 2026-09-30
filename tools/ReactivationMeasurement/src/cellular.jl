# A second system: an elementary cellular automaton on a ring (RSB-GEN-001 §9 step 7).
#
# It exists to show that the engine is generic: it meets the `AbstractSystem` contract and is
# measured by the same response layer, without any change to that layer. It is never part of
# a registered profile.
#
# Silencing (the only intervention, see system.jl): a silenced cell sends 0 to its two
# neighbours, and still updates itself from its own actual state and what its neighbours send.

"""Elementary cellular automaton with Wolfram rule number `rule` on a ring of `n` cells."""
struct ElementaryCA <: AbstractSystem
    n::Int
    rule::Int
    function ElementaryCA(n::Integer, rule::Integer)
        3 <= n <= MAX_UNITS || throw(ArgumentError("a ring needs between 3 and $MAX_UNITS cells"))
        0 <= rule <= 255 || throw(ArgumentError("rule must be between 0 and 255"))
        new(Int(n), Int(rule))
    end
end

nunits(ca::ElementaryCA) = ca.n

"""Each cell influences its left and right neighbour."""
out_adjacency(ca::ElementaryCA) =
    [(1 << mod(i - 1, ca.n)) | (1 << mod(i + 1, ca.n)) for i in 0:(ca.n - 1)]

function step(ca::ElementaryCA, x::Integer, silenced::Integer)
    n = ca.n
    sent = Int(x) & ~Int(silenced)
    next = 0
    for i in 0:(n - 1)
        l = (sent >> mod(i - 1, n)) & 1
        c = (Int(x) >> i) & 1
        r = (sent >> mod(i + 1, n)) & 1
        (ca.rule >> (4l + 2c + r)) & 1 == 1 && (next |= 1 << i)
    end
    next
end
