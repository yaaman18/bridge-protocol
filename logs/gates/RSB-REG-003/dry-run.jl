# Rehearsal of the re-registration on a scratch copy of the repository (nothing is pushed; the real
# registry is not touched). The two proposed rows are appended to the copy's registry, every remote_url
# is pointed at a local bare remote, and the verifier runs as it would against the fixed remote.
using SubstrateRegistry
const SR = SubstrateRegistry
repo = normpath(joinpath(@__DIR__, "..", "..", ".."))
rows = read(joinpath(@__DIR__, "proposed-registry-rows.toml"), String)
gitenv = Dict(k => v for (k, v) in ENV if !startswith(k, "GIT_"))
git(dir, args...) = String(strip(read(setenv(`git -C $dir -c user.name=dry-run -c user.email=dry-run@example.invalid -c commit.gpgsign=false $(collect(String, args))`, gitenv), String)))
mktempdir() do root
    work = joinpath(root, "work"); bare = joinpath(root, "remote.git"); runner = joinpath(root, "runner")
    run(setenv(`git clone -q $repo $work`, gitenv))
    reg = joinpath(work, "specs", "substrate-registry.toml")
    text = read(reg, String) * rows
    write(reg, replace(text, "https://github.com/yaaman18/bridge-protocol.git" => bare))
    git(work, "add", "-A"); git(work, "commit", "-q", "-m", "dry-run registration")
    R = git(work, "rev-parse", "HEAD")
    run(setenv(`git clone -q --bare $work $bare`, gitenv))
    run(setenv(`git clone -q $bare $runner`, gitenv))
    for id in ("rsb-003-reactivation-substrate-v1-r2-plan-v2", "rsb-002-reactivation-substrate-v1-r2",
               "rsb-001-reactivation-substrate-v1")
        r = SR._verify(R; registration_id=id, runner_repo=runner, remote_url=bare, remote_ref="refs/heads/main")
        if r isa SR.VerifiedRegistration
            println(id, ": VERIFIED  analysis_schema=", r.analysis_schema_validation_version,
                    "  strength=", r.preregistration_strength, "  cases=", length(r.case_ids))
        else
            println(id, ": ", r.status, " ", r.code, "  ", r.detail)
        end
    end
end
