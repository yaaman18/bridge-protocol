#!/usr/bin/env julia

include(joinpath(@__DIR__, "..", "tools", "CategoryPipeline.jl"))
using .CategoryPipeline

function usage(io=stdout)
    println(io, "usage: julia --project=. bin/eriec-category-pipeline.jl <impact|check|accept|baseline>")
    println(io, "  impact    detect changes and write the work queue (default)")
    println(io, "  check     detect changes and run G1-G4 without accepting them")
    println(io, "  accept    run G1-G4 and update the baseline only after all gates pass")
    println(io, "  baseline  initialize/reset the baseline without running gates")
end

function main(args)
    root = normpath(joinpath(@__DIR__, ".."))
    command = isempty(args) ? "impact" : first(args)
    command in ("impact", "check", "accept", "baseline") || begin
        usage(stderr)
        return 64
    end
    manifest_path = joinpath(root, "specs", "category-impact.toml")
    ledger_path = joinpath(root, "specs", "ledger.toml")
    baseline_path = joinpath(root, "specs", "category-baseline.toml")
    report_path = joinpath(root, "specs", "category-impact-report.md")
    manifest = load_manifest(manifest_path)
    ledger = load_ledger(ledger_path)
    errors = validate_configuration(root, manifest, ledger)
    if !isempty(errors)
        foreach(error -> println(stderr, "configuration error: ", error), errors)
        return 2
    end
    document = joinpath(root, String(manifest["document"]))
    if command == "baseline"
        if isfile(baseline_path)
            println(stderr, "baseline already exists; use 'accept' to advance it through the gates")
            return 6
        end
        write_baseline(
            baseline_path,
            document;
            document_label=String(manifest["document"]),
        )
        println("baseline updated: ", relpath(baseline_path, root))
        return 0
    end

    impact = compute_impact(root, manifest, ledger, baseline_path)
    gates = command in ("check", "accept") ? run_gates(root, manifest, ledger, impact) : GateResult[]
    write_report(report_path, impact, ledger, gates)
    println("changed sections: ", isempty(impact.changed_sections) ? "none" : join(impact.changed_sections, ", "))
    println("impacted VPs: ", isempty(impact.impacted_vps) ? "none" : join(impact.impacted_vps, ", "))
    println("report: ", relpath(report_path, root))

    if !isempty(impact.removed_sections)
        println(stderr, "removed sections require manifest review: ", join(impact.removed_sections, ", "))
        return 3
    end
    if !isempty(impact.unmapped_sections)
        println(stderr, "new ledger VP required for: ", join(impact.unmapped_sections, ", "))
        return 4
    end
    if command in ("check", "accept") && any(!gate.passed for gate in gates)
        return 5
    end
    if command == "accept" && !isempty(impact.changed_sections)
        write_baseline(
            baseline_path,
            document;
            document_label=String(manifest["document"]),
        )
        println("baseline accepted after all gates passed")
    end
    0
end

exit(main(ARGS))
