using LinearAlgebra

@testset "observation artifact v1" begin
    function record(; t=1, basis=Matrix{Float64}(I, 2, 2))
        (
            t=t,
            T=[1.0 0.0; 0.0 1.0],
            V=[0.4, 0.6],
            O_hat=[0.4 0.0; 0.0 0.6],
            wld=(
                basis=basis,
                eigenvalues=[1.0, 1.0],
                dimension=size(basis, 2),
                nontrivial=!isempty(basis),
            ),
        )
    end

    fingerprint = observation_system_fingerprint(:sigma, [1.0, 2.0], (gain=0.5,))
    artifact = ObservationArtifact([record(t=0), record(t=1)], fingerprint)
    @test artifact.schema_version == 1
    @test artifact.phenomenal_claim == :not_certified
    @test length(fingerprint) == 64
    @test validate_observation_artifact(artifact)

    parsed = parse_observation_artifact_json(observation_artifact_json(artifact))
    @test parsed.system_fingerprint == fingerprint
    @test parsed.timeseries[2].t == 1
    @test parsed.timeseries[1].wld.dimension == 2

    certification = verify_certified_artifact(
        parse_certified_artifact("ERIEC_CERTIFIED_ARTIFACT\t1\ttest-boundary\n"),
    )
    certified_json = certified_observation_artifact_json(artifact, certification)
    certified_parsed = parse_observation_artifact_json(certified_json)
    @test certified_parsed.system_fingerprint == fingerprint
    @test occursin("\"phenomenal_claim\":\"not_certified\"", certified_json)
    @test occursin("\"schema_version\":1", certified_json)
    @test occursin("\"boundary\":\"lean_core_julia_shell\"", certified_json)

    collection = ObservationArtifactCollection([artifact, parsed])
    @test validate_observation_artifact_collection(collection)
    collection_json = observation_artifact_collection_json(
        collection;
        metadata=(reproducibility=[(accepted=true,)],),
    )
    parsed_collection = parse_observation_artifact_collection_json(collection_json)
    @test length(parsed_collection.artifacts) == 2
    @test parsed_collection.phenomenal_claim == :not_certified
    @test occursin("\"kind\":\"observation_artifact_collection\"", collection_json)
    @test occursin("\"phenomenal_claim\":\"not_certified\"", collection_json)
    certified_collection_json = certified_observation_artifact_collection_json(
        collection,
        certification,
    )
    @test length(
        parse_observation_artifact_collection_json(certified_collection_json).artifacts,
    ) == 2
    @test_throws ArgumentError observation_artifact_collection_payload(
        collection;
        metadata=(phenomenal_claim=:certified,),
    )

    mktempdir() do dir
        plain_path = joinpath(dir, "observation-v1.json")
        certified_path = joinpath(dir, "observation-v1-certified.json")
        @test write_observation_artifact(plain_path, artifact) == plain_path
        @test write_certified_observation_artifact(
            certified_path,
            artifact,
            certification,
        ) == certified_path
        @test parse_observation_artifact_json(read(plain_path, String)).system_fingerprint ==
              fingerprint
        @test parse_observation_artifact_json(
            read(certified_path, String),
        ).system_fingerprint == fingerprint
    end

    same_system = ObservationArtifact([record(basis=[1.0; 0.0;;])], fingerprint)
    same_diff = umwelt_relative_diff(artifact, same_system)
    @test !same_diff.relative
    @test same_diff.projection_norm_diff > 0
    changed_system = ObservationArtifact(
        [record(basis=[1.0; 0.0;;])],
        observation_system_fingerprint(:changed),
    )
    changed_diff = umwelt_relative_diff(artifact, changed_system)
    @test changed_diff.relative
    @test changed_diff.projection_norm_diff > 0

    @test_throws ArgumentError ObservationArtifact(
        [(t=1, T=zeros(1, 1), V=[1.0], O_hat=zeros(1, 1))],
        fingerprint,
    )
    @test_throws ArgumentError ObservationArtifact(
        [record()],
        fingerprint;
        phenomenal_claim=:certified,
    )
    changed_claim = replace(
        observation_artifact_json(artifact),
        "not_certified" => "certified",
    )
    @test_throws ArgumentError parse_observation_artifact_json(changed_claim)
    missing_claim = replace(
        observation_artifact_json(artifact),
        "\"phenomenal_claim\":\"not_certified\"," => "",
    )
    @test_throws ArgumentError parse_observation_artifact_json(missing_claim)
    changed_collection_claim = replace(
        collection_json,
        "\"phenomenal_claim\":\"not_certified\"" =>
            "\"phenomenal_claim\":\"certified\"";
        count=1,
    )
    @test_throws ArgumentError parse_observation_artifact_collection_json(
        changed_collection_claim,
    )
    missing_channel = replace(
        observation_artifact_json(artifact),
        r"\"O_hat\":\[[^\]]*\](?:,[^,}]*)?" => "",
    )
    @test_throws ArgumentError parse_observation_artifact_json(missing_channel)
end
