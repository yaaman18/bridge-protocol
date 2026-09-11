using Test
using TOML
include(joinpath(@__DIR__, "..", "tools", "ClaimAudit.jl"))

function claim_audit_context(; observation="symmetry with initial state")
    ModelAudit.AuditContext(question_id="q-symmetry", question="不変な支持候補が存在するか",
        definition_version="v1", definition="全自己同型で固定される候補支持", assumptions=("候補クラスを固定",),
        observation=observation, subject="二つの対称なフィードバック回路")
end

function claim_audit_fixture(; overrides...)
    fields = merge((claim_id="claim-1", context=claim_audit_context(), proposition="固定候補が存在する",
        verdict=:affirmed, reason="測定例の固定候補を確認", evidence=("fixture:symmetry",)), (; overrides...))
    ClaimAudit.AuditClaim(; fields...)
end

@testset "persistent claims retain context and evidence" begin
    a = claim_audit_fixture()
    record = ClaimAudit.claim_record(a)
    @test ClaimAudit.claim_record(ClaimAudit.parse_claim_record(record)) == record
    @test ClaimAudit.claim_record(ClaimAudit.parse_claim_record(record; expected_digest=record["digest"])) == record
    @test_throws ArgumentError ClaimAudit.parse_claim_record(record; expected_digest=repeat("0",64))
    @test_throws ArgumentError claim_audit_fixture(evidence=())
    @test claim_audit_fixture(verdict=:undetermined, evidence=()).verdict == :undetermined
    refs = ["ref1"]
    frozen = claim_audit_fixture(evidence=refs)
    push!(refs,"ref2")
    @test frozen.evidence == ("ref1",)
    b = claim_audit_fixture(claim_id="claim-2", verdict=:denied)
    conflict = ClaimAudit.compare_claim_records(a,b)
    @test conflict["classification"] == "conflict_requires_review"
    @test conflict["left"]["evidence"] == ["fixture:symmetry"]
    @test conflict["right"]["context"]["question"] == a.context.question
    @test !conflict["residual_status_updated"] && !conflict["evidence_verified"]
    @test conflict["interpretation"] == "requires_review"
    different = claim_audit_fixture(claim_id="claim-3", verdict=:denied,
        context=claim_audit_context(observation="symmetry of dynamics only"))
    compared = ClaimAudit.compare_claim_records(a,different)
    @test compared["classification"] == "different_context" && compared["differences"] == ["observation"]
    @test compared["opposite_verdicts"] && !compared["same_context"]
    @test_throws ArgumentError ClaimAudit.compare_claim_records(a,claim_audit_fixture(verdict=:denied))
    @test ClaimAudit.compare_claim_records(a,a)["classification"] == "compatible"
    for mutate in (
        r -> (r["reason"] = "差替え"), r -> (r["schema_version"] = true),
        r -> (r["verdict"] = "unknown"), r -> (r["phenomenal_claim"] = "certified"),
        r -> (r["evidence"] = String[]), r -> (r["context"]["extra"] = "ignored"),
        r -> (r["extra"] = "ignored"), r -> (r["digest"] = repeat("0",64)))
        bad = deepcopy(record); mutate(bad)
        @test_throws ArgumentError ClaimAudit.parse_claim_record(bad)
    end
    mktempdir() do dir
        left_path, right_path = joinpath(dir,"left.toml"), joinpath(dir,"right.toml")
        open(io -> TOML.print(io,record; sorted=true),left_path,"w")
        open(io -> TOML.print(io,ClaimAudit.claim_record(different); sorted=true),right_path,"w")
        root = dirname(@__DIR__)
        cli = joinpath(root,"bin","eriec-claim-audit.jl")
        parsed = TOML.parse(read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli compare $left_path $right_path`,String))
        @test parsed["classification"] == "different_context"
        @test parsed["left"]["digest"] == record["digest"]
        checked = TOML.parse(read(`$(Base.julia_cmd()) --startup-file=no --project=$root $cli check $left_path $(record["digest"])`,String))
        @test checked["valid_record"] && checked["external_digest_checked"]
    end
end
