# Command line entry used by bin/eriec-substrate-registry.jl through the isolated project.

const USAGE = """
usage:
  eriec-substrate-registry verify <registration_commit> <registration_id> <runner_repo>
  eriec-substrate-registry validate-profile <path>
  eriec-substrate-registry validate-analysis <path>
exit codes: 0 verified/valid, 1 failed or invalid, 2 unverified (remote not consulted), 64 usage
"""

function _report(io::IO, result)
    d = Dict{String,Any}("phenomenal_claim" => "not_certified")
    if result isa VerifiedRegistration
        d["status"] = "VERIFIED"
        for name in fieldnames(VerifiedRegistration)
            name === :case_ids && continue
            d[String(name)] = getfield(result, name)
        end
        d["case_count"] = length(result.case_ids)
        d["case_digest"] = case_digest(result.case_ids)
    else
        d["status"] = String(result.status)
        d["code"] = String(result.code)
        d["detail"] = result.detail
    end
    TOML.print(io, d; sorted=true)
end

function main(args::Vector{String}; io::IO=stdout)
    if length(args) == 4 && args[1] == "verify"
        result = verify_substrate_registration(args[2]; registration_id=args[3], runner_repo=args[4])
        _report(io, result)
        result isa VerifiedRegistration && return 0
        return result.status === :UNVERIFIED ? 2 : 1
    elseif length(args) == 2 && args[1] in ("validate-profile", "validate-analysis")
        validate = args[1] == "validate-profile" ? validate_profile : validate_analysis_plan
        try
            validate(read(args[2]))
            println(io, "valid")
            return 0
        catch e
            e isa SchemaViolation || rethrow()
            showerror(io, e)
            println(io)
            return 1
        end
    end
    print(io, USAGE)
    64
end
