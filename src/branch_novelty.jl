"""One closed finite generation of sigma-only branch observations."""
struct FiniteBranchObservation{M,E,A,S}
    motors::Vector{M}
    environments::Vector{E}
    alpha_rel::A
    sigma_rel::S
end

function FiniteBranchObservation(motors, environments, alpha_rel, sigma_rel)
    FiniteBranchObservation(collect(motors), collect(environments), alpha_rel, sigma_rel)
end

"""A lineage-fixed identity map from generation-local environments to one medium."""
struct FiniteEnvironmentIdentity{F}
    identify::F
end

"""Derived finite prefix result; scores are cumulative distinct branch images."""
struct FiniteBranchScore
    images_by_generation::Vector{Vector{Set{Any}}}
    history::Vector{Set{Any}}
    scores::Vector{Int}
    novel_counts::Vector{Int}
    lost_counts::Vector{Int}
end

function _branch_novelty_unique(values)
    items = collect(values)
    length(unique(items)) == length(items)
end

function _branch_novelty_membership(relation, left, right)
    values = relation(left)
    right in values
end

"""Exact finite check of hConv on the declared closed carriers."""
function check_branch_observation(observation::FiniteBranchObservation)::Bool
    _branch_novelty_unique(observation.motors) || return false
    _branch_novelty_unique(observation.environments) || return false
    try
        all(
            begin
            alpha = _branch_novelty_membership(
                observation.alpha_rel, motor, environment)
            sigma = _branch_novelty_membership(
                observation.sigma_rel, environment, motor)
            alpha == sigma
            end
            for motor in observation.motors
            for environment in observation.environments
        )
    catch
        false
    end
end

function _branch_novelty_key(identity::FiniteEnvironmentIdentity, generation, environment)
    identity.identify(generation, environment)
end

"""Validate that every generation embeds its complete environment carrier."""
function check_environment_identity(
    observations::AbstractVector{<:FiniteBranchObservation},
    identity::FiniteEnvironmentIdentity,
)::Bool
    try
        all(enumerate(observations)) do (generation, observation)
            keys = [
                _branch_novelty_key(identity, generation, environment)
                for environment in observation.environments
            ]
            length(unique(keys)) == length(keys)
        end
    catch
        false
    end
end

"""Every finite generation must enumerate the same closed environment carrier."""
function check_shared_environment_carrier(
    observations::AbstractVector{<:FiniteBranchObservation},
)::Bool
    isempty(observations) && return false
    baseline = Set(first(observations).environments)
    all(observation -> Set(observation.environments) == baseline, observations)
end

function _branch_image_equal(left::Set{Any}, right::Set{Any})
    left == right
end

function _branch_image_member(image::Set{Any}, images::Vector{Set{Any}})
    any(candidate -> _branch_image_equal(image, candidate), images)
end

function _branch_images(
    observation::FiniteBranchObservation,
    identity::FiniteEnvironmentIdentity,
    generation::Int,
)
    images = Set{Any}[]
    for motor in observation.motors
        fibre = [
            environment for environment in observation.environments
            if _branch_novelty_membership(observation.sigma_rel, environment, motor)
        ]
        length(fibre) >= 2 || continue
        image = Set{Any}(
            _branch_novelty_key(identity, generation, environment)
            for environment in fibre
        )
        _branch_image_member(image, images) || push!(images, image)
    end
    images
end

"""
Compute cumulative distinct branch images on a closed finite prefix.

Lost images remain in `history`; a later equal image is therefore not novel.
"""
function finite_branch_score(
    observations::AbstractVector{<:FiniteBranchObservation},
    identity::FiniteEnvironmentIdentity,
)
    isempty(observations) && throw(ArgumentError("observations must be nonempty"))
    all(check_branch_observation, observations) ||
        throw(ArgumentError("every observation must satisfy finite hConv"))
    check_environment_identity(observations, identity) ||
        throw(ArgumentError("environment identity must be injective per generation"))

    images_by_generation = Vector{Vector{Set{Any}}}()
    history = Set{Any}[]
    scores = Int[]
    novel_counts = Int[]
    lost_counts = Int[]
    previous = Set{Any}[]

    for (generation, observation) in enumerate(observations)
        current = _branch_images(observation, identity, generation)
        novel = count(image -> !_branch_image_member(image, history), current)
        lost = count(image -> !_branch_image_member(image, current), previous)
        for image in current
            _branch_image_member(image, history) || push!(history, image)
        end
        push!(images_by_generation, current)
        push!(scores, length(history))
        push!(novel_counts, novel)
        push!(lost_counts, lost)
        previous = current
    end

    FiniteBranchScore(
        images_by_generation,
        copy(history),
        scores,
        novel_counts,
        lost_counts,
    )
end

"""Exactly compare a claimed finite score trace with the derived trace."""
function check_finite_branch_score(
    observations::AbstractVector{<:FiniteBranchObservation},
    identity::FiniteEnvironmentIdentity;
    scores,
    novel_counts,
    lost_counts,
)::Bool
    try
        derived = finite_branch_score(observations, identity)
        derived.scores == collect(scores) &&
            derived.novel_counts == collect(novel_counts) &&
            derived.lost_counts == collect(lost_counts)
    catch
        false
    end
end

"""Finite-prefix witness: some generation at or after `cutoff` has a new image."""
function check_branch_fresh_prefix(score::FiniteBranchScore; cutoff::Integer=1)::Bool
    1 <= cutoff <= length(score.novel_counts) || return false
    any(>(0), @view score.novel_counts[cutoff:end])
end

"""Validate and compute a complete finite loss-aware branch novelty route."""
function check_branch_novelty_route(
    observations::AbstractVector{<:FiniteBranchObservation},
    identity::FiniteEnvironmentIdentity;
    cutoff::Integer=1,
)::Bool
    try
        score = finite_branch_score(observations, identity)
        check_branch_fresh_prefix(score; cutoff=cutoff)
    catch
        false
    end
end

"""
Validate the certified finite route boundary.

The environment carrier is literally shared and structural identity is the
identity map, so a caller cannot separate generations by supplying a custom
medium embedding.
"""
function check_canonical_branch_novelty_route(
    observations::AbstractVector{<:FiniteBranchObservation};
    cutoff::Integer=1,
)::Bool
    check_shared_environment_carrier(observations) || return false
    identity = FiniteEnvironmentIdentity((_, environment) -> environment)
    check_branch_novelty_route(observations, identity; cutoff=cutoff)
end
