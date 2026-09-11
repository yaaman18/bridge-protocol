include(joinpath(@__DIR__,"..","..","..","tools","AuditViewer.jl"))
path = normpath(joinpath(@__DIR__,"..","..","reviews","reactivation-model-audit-viewer.html"))
data = AuditViewer.write_audit_viewer(path)
println("PASS cases=",data["case_count"]," branches=",data["total_branch_count"],
    " digest=",data["generation_digest"]," path=",path)
