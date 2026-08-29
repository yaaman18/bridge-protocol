module PacketReviewValidation

using TOML

export PacketReviewCheck, packet_review_checks, validate_packet_review

struct PacketReviewCheck
    code::String
    ok::Bool
    subject::String
    detail::String
end

function add_check!(checks, code, ok, subject, detail)
    push!(checks, PacketReviewCheck(code, ok, subject, detail))
end

default_project_root() = normpath(joinpath(@__DIR__, "..", ".."))

function nonempty_string(value)
    return value isa AbstractString && !isempty(strip(value))
end

function path_is_repo_file(root::AbstractString, relative_path)
    nonempty_string(relative_path) || return false
    isabspath(relative_path) && return false
    candidate = normpath(joinpath(root, relative_path))
    relative_candidate = relpath(candidate, root)
    escapes_root = relative_candidate == ".." ||
        startswith(relative_candidate, ".." * string(Base.Filesystem.path_separator))
    escapes_root && return false
    isfile(candidate) || return false
    resolved_root = realpath(root)
    resolved = realpath(candidate)
    relative_resolved = relpath(resolved, resolved_root)
    return relative_resolved != ".." &&
        !startswith(relative_resolved, ".." * string(Base.Filesystem.path_separator))
end

"""Return every validation check performed for a packet review sidecar."""
function packet_review_checks(
    sidecar_path::AbstractString;
    project_root::AbstractString=default_project_root(),
    registry_path::AbstractString=joinpath(
        project_root,
        "specs",
        "verification-failure-modes.toml",
    ),
    mutation_corpus_path::AbstractString=joinpath(
        project_root,
        "tools",
        "mutation_corpus.toml",
    ),
)
    root = normpath(abspath(project_root))
    sidecar = TOML.parsefile(sidecar_path)
    registry = TOML.parsefile(registry_path)
    corpus = TOML.parsefile(mutation_corpus_path)
    reviews = get(sidecar, "failure_mode_review", Any[])
    registered_ids = [get(mode, "id", "") for mode in get(registry, "failure_mode", Any[])]
    mutation_ids = Set(
        get(mutation, "id", "") for mutation in get(corpus, "mutation", Any[])
    )
    checks = PacketReviewCheck[]
    review_ids = [get(review, "id", "") for review in reviews]
    packet_id = string(get(sidecar, "packet_id", basename(sidecar_path)))

    for registered_id in registered_ids
        add_check!(
            checks,
            "FM_REVIEW_MISSING_ID",
            count(==(registered_id), review_ids) >= 1,
            registered_id,
            "every registered failure-mode id must be reviewed",
        )
    end

    for (index, review) in enumerate(reviews)
        review_id = get(review, "id", "")
        subject = nonempty_string(review_id) ? review_id : "$packet_id#$index"
        add_check!(
            checks,
            "FM_REVIEW_UNKNOWN_ID",
            review_id in registered_ids,
            subject,
            "review ids must occur in the failure-mode registry",
        )
        add_check!(
            checks,
            "FM_REVIEW_RATIONALE_MISSING",
            nonempty_string(get(review, "rationale_ja", "")),
            subject,
            "rationale_ja is required and must not be empty",
        )
        applicable = get(review, "applicable", false)
        add_check!(
            checks,
            "FM_REVIEW_MITIGATION_MISSING",
            applicable !== true || nonempty_string(get(review, "mitigation_ja", "")),
            subject,
            "applicable reviews require a non-empty mitigation_ja",
        )
        for mutation_id in get(review, "mutation_ids", Any[])
            add_check!(
                checks,
                "FM_REVIEW_UNKNOWN_MUTATION",
                mutation_id in mutation_ids,
                string(mutation_id),
                "mutation_ids entries must occur in the mutation corpus",
            )
        end
    end

    for review_id in unique(review_ids)
        add_check!(
            checks,
            "FM_REVIEW_DUPLICATE_ID",
            count(==(review_id), review_ids) == 1,
            nonempty_string(review_id) ? review_id : packet_id,
            "each failure-mode id must occur exactly once",
        )
    end

    prose = get(sidecar, "prose", "")
    add_check!(
        checks,
        "FM_REVIEW_PROSE_MISSING",
        path_is_repo_file(root, prose),
        packet_id,
        "prose must be a repository-relative path to an existing repository file",
    )

    return checks
end

function validate_packet_review(
    sidecar_path::AbstractString;
    kwargs...,
)
    return filter(check -> !check.ok, packet_review_checks(sidecar_path; kwargs...))
end

end
