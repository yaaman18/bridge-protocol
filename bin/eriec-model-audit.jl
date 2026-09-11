#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__, "..", "tools", "ModelAudit.jl"))

function main(args)
    if args == ["examples"]
        report = ModelAudit.model_witness_report()
        TOML.print(stdout, report; sorted=true)
        return report["all_expected_patterns_matched"] ? 0 : 1
    elseif length(args) == 3 && args[1] == "symmetry"
        circuit = ModelAudit.parse_audit_circuit(TOML.parsefile(args[2]))
        choices = TOML.parsefile(args[3])
        ModelAudit._exact_keys(choices, ("supports", "include_initial"))
        choices["include_initial"] isa Bool || throw(ArgumentError("include_initial must be Boolean"))
        report = ModelAudit.symmetry_audit_report(ModelAudit.audit_candidate_supports(circuit,
            choices["supports"]; include_initial=choices["include_initial"]))
        TOML.print(stdout, report; sorted=true)
        return 0
    elseif args == ["measured-witnesses"]
        TOML.print(stdout, ModelAudit.measured_witness_corpus(); sorted=true)
        return 0
    elseif length(args) == 2 && args[1] in ("verify-measurement", "verify-search")
        data = TOML.parsefile(args[2])
        verify = args[1] == "verify-measurement" ? ModelAudit.verify_measurement_report : ModelAudit.verify_search_report
        verify(data)
        TOML.print(stdout, Dict("replay_matched" => true, "phenomenal_claim" => "not_certified",
            "execution_certified" => false); sorted=true)
        return 0
    elseif length(args) == 2 && args[1] == "measure"
        circuit = ModelAudit.parse_audit_circuit(TOML.parsefile(args[2]))
        report = ModelAudit.circuit_measurement_report(ModelAudit.measure_circuit(circuit))
        TOML.print(stdout, report; sorted=true)
        return report["valid"] ? 0 : 1
    elseif length(args) in (2, 3, 4) && args[1] == "search"
        limit = length(args) >= 3 ? parse(Int, args[3]) : nothing
        seed = length(args) == 4 ? parse(Int, args[4]) : 20260910
        report = ModelAudit.measured_search_report(ModelAudit.search_measured_models(;
            domain=Symbol(args[2]), limit, seed))
        TOML.print(stdout, report; sorted=true)
        return 0
    elseif length(args) in (2, 4) && args[1] == "check-history"
        receipt = length(args) == 4 ? (count=parse(Int, args[3]), head=args[4]) : nothing
        history = ModelAudit.parse_audit_history(read(args[2], String); expected_receipt=receipt)
        summary = ModelAudit.audit_history_summary(history)
        result = Dict("valid_history" => true, "event_count" => summary.event_count,
            "question_count" => summary.question_count, "unresolved_count" => summary.unresolved_count,
            "counts" => summary.counts, "interpretation" => String(summary.interpretation),
            "phenomenal_claim" => "not_certified", "trusted_receipt_checked" => receipt !== nothing)
        TOML.print(stdout, result; sorted=true)
        return 0
    end
    println(stderr, "Usage: julia --project=. bin/eriec-model-audit.jl examples")
    println(stderr, "       julia --project=. bin/eriec-model-audit.jl check-history FILE [COUNT HEAD]")
    println(stderr, "       julia --project=. bin/eriec-model-audit.jl measure CIRCUIT.toml")
    println(stderr, "       julia --project=. bin/eriec-model-audit.jl search DOMAIN [LIMIT [SEED]]")
    println(stderr, "       julia --project=. bin/eriec-model-audit.jl measured-witnesses")
    println(stderr, "       julia --project=. bin/eriec-model-audit.jl verify-measurement REPORT.toml")
    println(stderr, "       julia --project=. bin/eriec-model-audit.jl verify-search REPORT.toml")
    println(stderr, "       julia --project=. bin/eriec-model-audit.jl symmetry CIRCUIT.toml SUPPORTS.toml")
    2
end

try
    exit(main(ARGS))
catch err
    println(stderr, "Model audit failed: ", sprint(showerror, err))
    exit(1)
end
