using TOML

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const LEDGER_REL = joinpath("specs", "claim-ledger-v2.toml")

function command_output(arguments::Vector{String})
    return strip(read(pipeline(Cmd(arguments); stderr=devnull), String))
end

function unverified(reason)
    println(stderr, "UNVERIFIED reason=$reason")
    return 2
end

function parse_base_ref(args)
    length(args) == 2 || return nothing
    args[1] == "--base-ref" || return nothing
    isempty(args[2]) && return nothing
    occursin(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$", args[2]) || return nothing
    occursin("..", args[2]) && return nothing
    return args[2]
end

function explicit_pending_max(ledger)
    migration = get(ledger, "migration", nothing)
    migration isa AbstractDict || return nothing
    value = get(migration, "falsification_pending_max", nothing)
    return value isa Integer ? value : nothing
end

function run_ratchet(args)
    base_ref = parse_base_ref(args)
    base_ref === nothing && return unverified("missing_or_invalid_base_ref")

    base_sha = try
        command_output([
            "git",
            "-C",
            REPO_ROOT,
            "rev-parse",
            "--verify",
            "--end-of-options",
            "$(base_ref)^{commit}",
        ])
    catch error
        return unverified("base_ref_unavailable")
    end

    base_text = try
        command_output([
            "git",
            "-C",
            REPO_ROOT,
            "show",
            "--no-ext-diff",
            "--no-textconv",
            "$base_sha:$LEDGER_REL",
        ])
    catch error
        return unverified("base_ledger_unavailable")
    end

    base_ledger = try
        TOML.parse(base_text)
    catch error
        return unverified("base_ledger_unparseable")
    end
    current_ledger = try
        TOML.parsefile(joinpath(REPO_ROOT, LEDGER_REL))
    catch error
        return unverified("current_ledger_unparseable")
    end

    current_max = explicit_pending_max(current_ledger)
    current_max === nothing && return unverified("current_pending_max_missing")

    # The one-shot migration bootstrap that derived a base count from the
    # pre-falsification schema was removed once the base carried [migration]
    # explicitly. It is preserved in commit d795f0bcc86a6b10403773d0887b1ccfb267cfd8.
    base_max = explicit_pending_max(base_ledger)
    base_max === nothing && return unverified("base_pending_max_missing")
    base_mode = "explicit"

    current_claims = get(current_ledger, "claim", Any[])
    current_pending = count(
        claim -> get(claim, "falsification_ja", "") == "未記入",
        current_claims,
    )
    println(
        "base_ref=$base_ref base_sha=$base_sha base_mode=$base_mode " *
        "base_pending_max=$base_max current_pending_max=$current_max " *
        "current_pending=$current_pending",
    )

    if current_pending > current_max
        println(stderr, "FAIL current pending count exceeds current_pending_max")
        return 1
    end
    if current_max > base_max
        println(stderr, "FAIL falsification_pending_max increased")
        return 1
    end

    println("PASS ratchet current_pending_max=$current_max base_pending_max=$base_max")
    return 0
end

exit(run_ratchet(ARGS))
