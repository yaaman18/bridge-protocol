# git access. System and global git configuration are ignored so that local settings such as
# `url.<base>.insteadOf` cannot redirect the fixed remote (RSB-001 §7(2), §10).

const _NULL_CONFIG = Sys.iswindows() ? "NUL" : "/dev/null"

function _git_env()
    env = Dict{String,String}(k => v for (k, v) in ENV if !startswith(k, "GIT_"))
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_CONFIG_GLOBAL"] = _NULL_CONFIG
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["LC_ALL"] = "C"
    env
end

struct GitResult
    ok::Bool
    exitcode::Int
    out::Vector{UInt8}
    err::String
end

function _git(args::Vector{String}; dir::Union{Nothing,String}=nothing)
    cmd = dir === nothing ? `git $args` : `git -C $dir $args`
    out = IOBuffer()
    err = IOBuffer()
    proc = run(pipeline(ignorestatus(setenv(cmd, _git_env())); stdout=out, stderr=err))
    GitResult(proc.exitcode == 0, proc.exitcode, take!(out), String(take!(err)))
end

_text(r::GitResult) = String(strip(String(copy(r.out))))

"""Return (mode, blob_oid) of `path` in `commit`, or `nothing` if absent."""
function _tree_entry(repo::String, commit::String, path::String)
    r = _git(["ls-tree", "-z", commit, "--", path]; dir=repo)
    r.ok || return nothing
    for entry in split(String(copy(r.out)), '\0'; keepempty=false)
        meta, name = split(entry, '\t'; limit=2)
        name == path || continue
        mode, kind, oid = split(meta, ' ')
        kind == "blob" || return (mode, "")
        return (String(mode), String(oid))
    end
    nothing
end

function _blob_bytes(repo::String, oid::String)
    r = _git(["cat-file", "blob", oid]; dir=repo)
    r.ok || error("cannot read blob $oid")
    r.out
end

_has_commit(repo::String, sha::String) =
    _git(["cat-file", "-e", "$(sha)^{commit}"]; dir=repo).ok

function _is_ancestor(repo::String, ancestor::String, descendant::String)
    r = _git(["merge-base", "--is-ancestor", ancestor, descendant]; dir=repo)
    r.exitcode == 0 && return true
    r.exitcode == 1 && return false
    error("merge-base failed: $(r.err)")
end
