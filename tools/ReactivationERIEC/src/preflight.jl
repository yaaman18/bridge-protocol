# Pre-registration check (read-only). Lists everything that would stop the analysis plan v2 from
# being registered with this criterion package: unfilled fields, schema, the pairing with the profile,
# the bound package tree at HEAD and a clean working tree there, the criterion versions and result keys
# the package actually defines, and the dependency paths. It changes nothing.

"""
    preflight(repo; plan_path, profile_path) -> Dict("ok" => Bool, "problems" => [...])

`plan_path` and `profile_path` are relative to `repo`.
"""
function preflight(repo::AbstractString; plan_path::AbstractString, profile_path::AbstractString)
    problems = String[]
    raw = read(joinpath(repo, plan_path), String)
    pending(x) = x isa AbstractDict ? any(pending, values(x)) : x isa AbstractVector ? any(pending, x) :
                 x isa String && startswith(x, "PENDING")
    pending(TOML.parse(raw)) && push!(problems, "the plan still contains PENDING fields")
    plan = try
        SubstrateRegistry.validate_analysis_plan(Vector{UInt8}(raw); version="rsb-analysis-schema-v2")
    catch e
        e isa SubstrateRegistry.SchemaViolation || rethrow()
        append!(problems, "schema: " .* e.errors)
        return Dict{String,Any}("ok" => false, "problems" => problems)
    end
    profile_bytes = read(joinpath(repo, profile_path))
    try
        profile = SubstrateRegistry.validate_profile(profile_bytes;
            version=SubstrateRegistry.profile_schema_version_of(profile_bytes))
        SubstrateRegistry.validate_pair(profile, plan)
    catch e
        e isa SubstrateRegistry.SchemaViolation || rethrow()
        append!(problems, "profile/plan pair: " .* e.errors)
    end
    defined = Dict("dc" => (DCCriterion(), DC_VALUE_KEYS, DC_DIAGNOSTIC_KEYS),
                   "dc2" => (DC2Criterion(), DC2_VALUE_KEYS, DC2_DIAGNOSTIC_KEYS))
    for b in plan["criterion_binding"]
        id, path = b["criterion_id"], b["package_path"]
        b["package_name"] == "ReactivationERIEC" ||
            push!(problems, "$id: package_name is not ReactivationERIEC")
        head = SubstrateRegistry.tree_oid_at(repo, "HEAD", path)
        head == b["package_tree_oid"] ||
            push!(problems, "$id: tree of $path at HEAD is $(something(head, "absent")), the plan says $(b["package_tree_oid"])")
        dirty = read(setenv(`git -C $repo status --porcelain --untracked-files=all -- $path`, ENV), String)
        isempty(dirty) || push!(problems, "$id: $path has uncommitted changes")
        if haskey(defined, id)
            c, vk, dk = defined[id]
            RM.criterion_version(c) == b["criterion_version"] ||
                push!(problems, "$id: the package defines version $(RM.criterion_version(c)), the plan says $(b["criterion_version"])")
            sort(vk) == sort(b["value_keys"]) || push!(problems, "$id: value_keys differ from the package")
            sort(dk) == sort(b["diagnostic_keys"]) || push!(problems, "$id: diagnostic_keys differ from the package")
        else
            push!(problems, "$id: this package defines no such criterion")
        end
        for dep in b["dependency_paths"]
            SubstrateRegistry.tree_oid_at(repo, "HEAD", dep) === nothing &&
                push!(problems, "$id: dependency path $dep is not a directory at HEAD")
        end
    end
    Dict{String,Any}("ok" => isempty(problems), "problems" => problems)
end
