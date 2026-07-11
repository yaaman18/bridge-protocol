using Test

include(joinpath(@__DIR__, "..", "tools", "CategoryPipeline.jl"))
using .CategoryPipeline

@testset "category update pipeline" begin
    root = normpath(joinpath(@__DIR__, ".."))
    manifest = load_manifest(joinpath(root, "specs", "category-impact.toml"))
    ledger = load_ledger(joinpath(root, "specs", "ledger.toml"))

    @test isempty(validate_configuration(root, manifest, ledger))
    sections = category_sections(joinpath(root, String(manifest["document"])))
    @test length(sections) == 21
    @test haskey(sections, "§0")
    @test haskey(sections, "§20")
    mapped_sections = Dict(String(entry["id"]) => entry for entry in manifest["section"])
    @test mapped_sections["§0"]["all_vps"] === true
    @test mapped_sections["§17"]["vp_ids"] == ["VP-OPD-001"]
    @test mapped_sections["§18"]["vp_ids"] == ["VP-AUD-001"]
    @test mapped_sections["§19"]["vp_ids"] == ["VP-LIN-001"]
    @test mapped_sections["§20"]["vp_ids"] == ["VP-TTR-001"]
    expected_new_vps = [
        "VP-ADJ-002", "VP-GRA-001", "VP-KT-001", "VP-GRA-002",
        "VP-CER-001", "VP-DYN-001", "VP-SEN-002", "VP-WLD-002",
        "VP-VAL-002", "VP-WDC-002", "VP-GUA-001", "VP-DEC-001",
        "VP-INV-001", "VP-REF-001",
    ]
    for vp_id in expected_new_vps
        @test haskey(ledger, vp_id)
        @test ledger[vp_id]["status"] in
            ["proposed", "formalized", "bound", "implemented", "certified", "failed"]
        @test startswith(ledger[vp_id]["source"], "category/三層構造の圏論的定式化_v5_1.md#§")
    end
    @test ledger["VP-OPD-001"]["julia_api"] == "FiniteOpenGraph"
    @test ledger["VP-AUD-001"]["julia_api"] == "FiniteSimulation"
    @test ledger["VP-LIN-001"]["lean_decl"] == "ERIEC.OpenEvolution.Lineage"
    @test ledger["VP-TTR-001"]["julia_api"] == "GuaranteeProfile"
    opd_impact = Impact(["§17"], String[], ["VP-OPD-001"], ["VP-OPD-001"], String[])
    @test CategoryPipeline._lean_targets_for_impact(ledger, opd_impact) == ["ERIEC.OpenDynamics"]

    mktempdir() do directory
        baseline = joinpath(directory, "baseline.toml")
        write_baseline(baseline, joinpath(root, String(manifest["document"])))
        impact = compute_impact(root, manifest, ledger, baseline)
        @test isempty(impact.changed_sections)
        @test isempty(impact.impacted_vps)
        @test isempty(impact.unmapped_sections)
    end

    mktempdir() do directory
        document = joinpath(directory, "category.md")
        write(document, "## §1. relation\nold\n## §17. open dynamics\nold\n")
        local_manifest = Dict{String,Any}(
            "schema_version" => 1,
            "document" => "category.md",
            "section" => Any[
                Dict("id" => "§1", "vp_ids" => ["VP-ADJ-001"], "tests" => String[]),
                Dict("id" => "§17", "vp_ids" => String[], "tests" => String[]),
            ],
        )
        baseline = joinpath(directory, "baseline.toml")
        write_baseline(baseline, document; document_label="category.md")
        write(document, "## §1. relation\nnew\n## §17. open dynamics\nnew\n")
        impact = compute_impact(directory, local_manifest, ledger, baseline)
        @test impact.changed_sections == ["§1", "§17"]
        @test impact.direct_vps == ["VP-ADJ-001"]
        @test "VP-WDC-001" in impact.impacted_vps
        @test impact.unmapped_sections == ["§17"]
        errors = validate_configuration(directory, local_manifest, ledger)
        @test any(error -> occursin("§17 has no VP mapping", error), errors)
    end

    mktempdir() do directory
        document = joinpath(directory, "category.md")
        write(document, "## §0. rules\nold\n")
        local_manifest = Dict{String,Any}(
            "schema_version" => 1,
            "document" => "category.md",
            "section" => Any[
                Dict("id" => "§0", "vp_ids" => String[], "tests" => String[], "all_vps" => true),
            ],
        )
        baseline = joinpath(directory, "baseline.toml")
        write_baseline(baseline, document; document_label="category.md")
        write(document, "## §0. rules\nnew\n")
        impact = compute_impact(directory, local_manifest, ledger, baseline)
        @test impact.direct_vps == sort!(collect(keys(ledger)))
        @test isempty(impact.unmapped_sections)
    end
end
