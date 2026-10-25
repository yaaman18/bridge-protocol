# The prototype substrate of AGENCY-001 §3.2: deterministic integer dynamics with a fast time scale
# (activity of units) and a slow one (strength of connections), and a shared resource.
#
# * Activity: a threshold network. An edge acts only while its strength is at least 1.
# * Resource (L1): every active unit costs 1 per step; an active motor harvests the current yield
#   of the environment patch it is coupled to (the patch's yield is the value of that coupling).
#   If the resource would go below 0 the system dies; death is absorbing (functional termination).
# * Structure (L3): an edge whose source was active and sending and whose target became active is
#   used; a used edge gains strength (up to `smax`, paying `grow_cost`), an unused edge loses 1 every
#   `decay_period` steps. Without activity, every edge eventually reaches 0. With `maintain = false`
#   strengths never change (structure given from outside).
# * Sensors are driven by the environment: a patch sensor is active while its patch has the highest
#   yield; a resource sensor is active while the resource is below (`mode = "low"`) or at least
#   (`mode = "high"`) its level. They still cost resource while active.
# * The only intervention is source silencing: a silenced unit keeps updating its own state but sends
#   nothing, and a silenced motor harvests nothing (harvesting is its output).

struct Params
    smax::Int
    decay_period::Int
    grow_cost::Int
    resource0::Int
    rmax::Int
    horizon::Int
    alive_window::Int
    strength0::Int
end

struct Substrate
    names::Vector{String}
    theta::Vector{Int}
    edges::Vector{NTuple{3,Int}}            # (source, target, weight), 1-based
    motors::Dict{Int,Int}                   # motor unit => patch
    patch_sensors::Dict{Int,Int}            # sensor unit => patch
    resource_sensors::Dict{Int,Tuple{Int,String}}  # unit => (level, "low" | "high")
    maintain::Bool
    initial::Vector{Bool}
end

nunits(s::Substrate) = length(s.names)
is_sensor(s::Substrate, u::Int) = haskey(s.patch_sensors, u) || haskey(s.resource_sensors, u)

mutable struct State
    active::Vector{Bool}
    strength::Vector{Int}
    resource::Int
    t::Int
    dead::Bool
end

initial_state(s::Substrate, p::Params) =
    State(copy(s.initial), fill(p.strength0, length(s.edges)), p.resource0, 0, false)

"""Yields of the two patches before and after `switch` (no switch when `first == second`)."""
struct Schedule
    name::String
    first::NTuple{2,Int}
    second::NTuple{2,Int}
    switch::Int
end

yield_of(sch::Schedule, patch::Int, t::Int) = (t < sch.switch ? sch.first : sch.second)[patch]

"""One step under `schedule` with the units in `silenced` sending nothing."""
function step!(st::State, s::Substrate, p::Params, sch::Schedule, silenced::Set{Int})
    if st.dead
        # A dead system has no activity, so nothing maintains its connections: they keep decaying.
        # (Fixed on 2026-10-09: the first version froze the structure at death, which made a dead
        # system's structure "persist"; found when the agent template's L3 disagreed with its label.)
        _decay_unused!(st, s, p, fill(false, length(s.edges)))
        st.t += 1
        return st
    end
    n = nunits(s)
    old = st.active
    total = zeros(Int, n)
    for (k, (src, dst, w)) in enumerate(s.edges)
        (st.strength[k] >= 1 && old[src] && !(src in silenced)) && (total[dst] += w)
    end
    new = Vector{Bool}(undef, n)
    for u in 1:n
        new[u] = if haskey(s.patch_sensors, u)
            patch = s.patch_sensors[u]
            yield_of(sch, patch, st.t) > yield_of(sch, 3 - patch, st.t)
        elseif haskey(s.resource_sensors, u)
            level, mode = s.resource_sensors[u]
            mode == "low" ? st.resource < level : st.resource >= level
        else
            total[u] >= s.theta[u]
        end
    end
    gain = sum((yield_of(sch, patch, st.t) for (m, patch) in s.motors if new[m] && !(m in silenced)); init=0)
    resource = st.resource + gain - count(new)
    if resource < 0
        st.dead = true
        st.active = fill(false, n)
        st.resource = 0
        st.t += 1
        return st
    end
    resource = min(resource, p.rmax)
    used = [old[src] && !(src in silenced) && new[dst] for (src, dst, _) in s.edges]
    if s.maintain
        for k in eachindex(s.edges)
            if used[k] && st.strength[k] < p.smax && resource >= p.grow_cost
                st.strength[k] += 1
                resource -= p.grow_cost
            end
        end
    end
    _decay_unused!(st, s, p, used)
    st.active = new
    st.resource = resource
    st.t += 1
    st
end

"""Unused connections lose 1 every `decay_period` steps (only when the structure is maintained by
activity at all; with `maintain = false` it is given from outside and never changes)."""
function _decay_unused!(st::State, s::Substrate, p::Params, used)
    (s.maintain && (st.t + 1) % p.decay_period == 0) || return
    for k in eachindex(s.edges)
        used[k] || (st.strength[k] = max(st.strength[k] - 1, 0))
    end
end

"""Run to the horizon; returns the trajectory of states (copies), starting with the initial one."""
function run_trajectory(s::Substrate, p::Params, sch::Schedule; silenced::Set{Int}=Set{Int}())
    st = initial_state(s, p)
    traj = [deepcopy(st)]
    for _ in 1:p.horizon
        step!(st, s, p, sch, silenced)
        push!(traj, deepcopy(st))
    end
    traj
end
