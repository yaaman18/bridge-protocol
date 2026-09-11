using Test
using Base64
using JSON3
isdefined(@__MODULE__, :AuditViewer) || include(joinpath(@__DIR__,"..","tools","AuditViewer.jl"))

@testset "self-contained audit viewer preserves the measured evidence" begin
    data = AuditViewer.audit_viewer_data()
    @test data["case_count"] == 7
    @test data["total_branch_count"] == 4480
    @test data["phenomenal_claim"] == "not_certified" && !data["execution_certified"]
    @test data["coordinate_semantics"] == "diagram_only_not_physical_space_or_decomposition"
    @test length(unique(c["name"] for c in data["cases"])) == 7
    for c in data["cases"]
        n = length(c["units"])
        @test c["branch_count"] == 1 << n == length(c["trace_masks"])
        @test all(length(trace) == c["H"]+1 for trace in c["trace_masks"])
        @test all(0 <= state < 1 << n for trace in c["trace_masks"] for state in trace)
        @test Set(c["kappa"]) ⊆ Set(c["units"])
        @test Set(c["future_Q"]) ⊆ Set(c["units"])
        @test Set(c["nu_phi"]) ⊆ Set(c["units"])
        @test c["all_interventions"] && c["adjunction_holds"]
    end
    html = AuditViewer.render_audit_viewer(data)
    @test occursin("Content-Security-Policy",html)
    @test occursin("connect-src 'none'",html)
    @test !occursin(r"<script\s+src",html)
    @test !occursin("fetch(",html) && !occursin("XMLHttpRequest",html) && !occursin("WebSocket",html)
    @test !occursin("innerHTML",html) && !occursin("eval(",html)
    encoded = only(match(r"const raw=atob\('([A-Za-z0-9+/=]+)'\)",html).captures)
    decoded = JSON3.read(String(base64decode(encoded)))
    @test decoded.generation_digest == data["generation_digest"]
    @test decoded.case_count == 7 && decoded.total_branch_count == 4480
    mktempdir() do dir
        path = joinpath(dir,"viewer.html")
        AuditViewer.write_audit_viewer(path)
        saved = read(path,String)
        @test startswith(saved,"<!doctype html>") && occursin(data["generation_digest"],String(base64decode(only(match(r"atob\('([A-Za-z0-9+/=]+)'\)",saved).captures))))
        script = only(match(r"<script>([\s\S]*)</script>",saved).captures)
        script_path = joinpath(dir,"viewer.js")
        write(script_path,script)
        @test success(run(ignorestatus(`node --check $script_path`);wait=true))
    end
end
