using SHA
using TOML

include(joinpath(@__DIR__, "claim_ledger_validation.jl"))
using .ClaimLedgerValidation

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const ALLOWED_TARGET = joinpath("specs", "claim-ledger-v2.toml")

file_sha256(path) = "sha256:" * bytes2hex(open(sha256, path))

function fail(message)
    println(stderr, "FAIL ", message)
    return 1
end

function run_mutations()
    corpus_path = joinpath(REPO_ROOT, "tools", "mutation_corpus.toml")
    corpus = TOML.parsefile(corpus_path)
    mutations = get(corpus, "mutation", Any[])
    isempty(mutations) && return fail("mutation corpus is empty")

    ids = [get(mutation, "id", "") for mutation in mutations]
    length(ids) == length(unique(ids)) || return fail("mutation ids are not unique")

    for mutation in mutations
        mutation_id = get(mutation, "id", "")
        target_rel = get(mutation, "target", "")
        expected_code = get(mutation, "expect_code", "")
        edit = get(mutation, "edit", Dict{String,Any}())
        find_text = get(edit, "find", "")
        replace_text = get(edit, "replace", "")

        isempty(mutation_id) && return fail("mutation id is missing")
        normpath(target_rel) == ALLOWED_TARGET ||
            return fail("mutation=$mutation_id target is outside the allowed ledger")
        isabspath(target_rel) && return fail("mutation=$mutation_id target must be relative")
        isempty(expected_code) && return fail("mutation=$mutation_id expect_code is missing")
        isempty(find_text) && return fail("mutation=$mutation_id find text is empty")
        find_text == replace_text && return fail("mutation=$mutation_id edit is a no-op")

        target_path = normpath(joinpath(REPO_ROOT, target_rel))
        isfile(target_path) || return fail("mutation=$mutation_id target does not exist")
        islink(target_path) && return fail("mutation=$mutation_id symlink targets are forbidden")
        realpath(target_path) == target_path ||
            return fail("mutation=$mutation_id target path is not canonical")

        before_sha = file_sha256(target_path)
        baseline = validate_claim_ledger(target_path; project_root=REPO_ROOT)
        isempty(baseline) || return fail(
            "mutation=$mutation_id baseline violations=" *
            join([violation.code for violation in baseline], ","),
        )

        original_text = read(target_path, String)
        occurrences = length(findall(find_text, original_text))
        occurrences == 1 || return fail(
            "mutation=$mutation_id expected one edit match, found $occurrences",
        )
        mutated_text = replace(original_text, find_text => replace_text; count=1)

        violations = mktempdir() do temporary_directory
            temporary_ledger = joinpath(temporary_directory, basename(target_path))
            write(temporary_ledger, mutated_text)
            validate_claim_ledger(temporary_ledger; project_root=REPO_ROOT)
        end
        violation_codes = [violation.code for violation in violations]
        violation_codes == [expected_code] || return fail(
            "mutation=$mutation_id expected=$expected_code actual=" *
            (isempty(violation_codes) ? "none" : join(violation_codes, ",")),
        )

        after_sha = file_sha256(target_path)
        before_sha == after_sha || return fail(
            "mutation=$mutation_id modified the live target",
        )
        println(
            "PASS mutation=$mutation_id expect_code=$expected_code live_sha=$after_sha",
        )
    end

    return 0
end

exit(run_mutations())
