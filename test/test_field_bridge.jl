using Test
using ERIEC
using Random

@testset "field to sensory bridge" begin
    profile = ERIEC.load_sensory_carrier_profile()
    @test profile.profile_id == "lenia-geometric-sensory-v1"
    @test profile.angular_sectors == 16
    @test profile.radial_bands == 4

    shape = (32, 32)
    system = default_lenia_system(shape; action_count=16, feature_count=32)
    field = lenia_initial_field(
        shape;
        config=LeniaInitialConditionConfig(
            mode=:gaussian_blob,
            amplitude=1.0,
            width=0.18,
        ),
    )
    obstacle_mask = falses(shape)
    obstacle_mask[12:20, 23] .= true
    obstacle = ERIEC.ObstacleField(obstacle_mask)

    extracted = ERIEC.extract_geometric_sensory(system, field, obstacle; profile=profile)
    @test extracted.valid
    @test length(extracted.state) == 68
    @test count(channel -> first(channel) == :boundary_sector, extracted.state.channels) == 16
    @test count(channel -> first(channel) == :radial_gradient, extracted.state.channels) == 4
    @test count(channel -> first(channel) == :normal_flux, extracted.state.channels) == 16
    @test count(channel -> first(channel) == :curvature_shape, extracted.state.channels) == 16
    @test count(channel -> first(channel) == :contact_obstacle, extracted.state.channels) == 16
    @test all(isfinite, extracted.state.values)

    geometry_result = ERIEC.extract_body_geometry(field, obstacle; profile=profile)
    boundary_certificate = ERIEC.PeriodicBoundaryCertificate(
        geometry_result;
        profile=profile,
    )
    @test ERIEC.check_periodic_body_boundary(boundary_certificate; profile=profile)

    translated_field = circshift(field, (5, -7))
    translated_obstacle = ERIEC.ObstacleField(circshift(obstacle.mask, (5, -7)))
    translated = ERIEC.extract_geometric_sensory(
        system,
        translated_field,
        translated_obstacle;
        profile=profile,
    )
    @test translated.valid
    @test translated.state.channels == extracted.state.channels
    @test translated.state.values ≈ extracted.state.values atol=1e-10

    action = zeros(length(system.action_basis))
    stepped = ERIEC.lenia_obstacle_step(system, field, action, obstacle)
    @test all(iszero, stepped[obstacle.mask])

    dead = ERIEC.extract_body_geometry(zeros(shape), obstacle; profile=profile)
    @test !dead.valid
    @test dead.reason == :body_support_absent
    println("FALSIFICATION-BDY-002-DEAD-SUPPORT: PASS")

    rng = MersenneTwister(20260901)
    random_fields = [0.1 .* rand(rng, shape...) for _ in 0:profile.persistence_horizon]
    random_persistence = ERIEC.check_body_persistence(
        random_fields,
        ERIEC.ObstacleField(falses(shape));
        profile=profile,
    )
    @test !random_persistence.ok
    @test random_persistence.reason in (
        :coherence_failed,
        :body_support_ambiguous,
        :body_center_undefined,
        :body_support_too_small,
    )
    println("FALSIFICATION-BDY-002-RANDOM-PERSISTENCE: PASS")
end

@testset "periodic body boundary witness" begin
    profile = ERIEC.load_sensory_carrier_profile()
    support = trues(3, 3)
    support[2, 3] = false
    boundary = falses(3, 3)
    boundary[1, 3] = true
    boundary[2, 1] = true
    boundary[2, 2] = true
    boundary[3, 3] = true
    certificate = ERIEC.PeriodicBoundaryCertificate(
        BitMatrix(support),
        BitMatrix(boundary),
        profile.profile_id,
        ERIEC.sensory_carrier_profile_sha256(),
    )
    @test ERIEC.check_periodic_body_boundary(certificate; profile=profile)
    @test certificate.boundary[2, 1]

    missing = copy(certificate.boundary)
    missing[2, 1] = false
    missing_certificate = ERIEC.PeriodicBoundaryCertificate(
        certificate.support,
        missing,
        certificate.profile_id,
        certificate.profile_sha256,
    )
    @test !ERIEC.check_periodic_body_boundary(missing_certificate; profile=profile)
    println("FALSIFICATION-BDY-003-MISSING-BOUNDARY: PASS")

    outside = copy(certificate.boundary)
    outside[2, 3] = true
    outside_certificate = ERIEC.PeriodicBoundaryCertificate(
        certificate.support,
        outside,
        certificate.profile_id,
        certificate.profile_sha256,
    )
    @test !ERIEC.check_periodic_body_boundary(outside_certificate; profile=profile)
    println("FALSIFICATION-BDY-003-OUTSIDE-SUPPORT: PASS")

    wrong_profile = ERIEC.PeriodicBoundaryCertificate(
        certificate.support,
        certificate.boundary,
        certificate.profile_id,
        repeat("0", 64),
    )
    @test !ERIEC.check_periodic_body_boundary(wrong_profile; profile=profile)
    println("FALSIFICATION-BDY-003-PROFILE-DIGEST: PASS")

    @testset "reject malformed masks and profile identity" begin
        for (label, invalid_support, invalid_boundary, profile_id) in (
            ("shape mismatch", support, falses(2, 2), profile.profile_id),
            ("zero-sized masks", falses(0, 0), falses(0, 0), profile.profile_id),
            ("empty support", falses(3, 3), boundary, profile.profile_id),
            ("empty boundary", support, falses(3, 3), profile.profile_id),
            ("nonsquare grid", trues(2, 3), trues(2, 3), profile.profile_id),
            ("profile ID mismatch", support, boundary, "wrong-profile"),
        )
            @testset "$label" begin
                invalid = ERIEC.PeriodicBoundaryCertificate(
                    invalid_support,
                    invalid_boundary,
                    profile_id,
                    certificate.profile_sha256,
                )
                @test !ERIEC.check_periodic_body_boundary(invalid; profile=profile)
            end
        end
    end

    @testset "wrap-around in all four directions" begin
        # The missing cell at [2, 3] makes [2, 1] a boundary through the seam.
        # Rotate both this witness and its missing-boundary falsification.
        for quarter_turns in 0:3
            rotated_support = BitMatrix(rotl90(support, quarter_turns))
            rotated_boundary = BitMatrix(rotl90(boundary, quarter_turns))
            rotated_missing = BitMatrix(rotl90(missing, quarter_turns))
            for (candidate, expected_ok) in ((rotated_boundary, true), (rotated_missing, false))
                rotated = ERIEC.PeriodicBoundaryCertificate(
                    rotated_support,
                    candidate,
                    certificate.profile_id,
                    certificate.profile_sha256,
                )
                @test ERIEC.check_periodic_body_boundary(rotated; profile=profile) == expected_ok
            end
        end
    end
    println("FALSIFICATION-BDY-003-PERIODIC-WRAP: PASS")

    artifact_check = verify_lean_certified_artifact()
    @test certified_artifact_ok(artifact_check)
    envelope = ERIEC.certified_periodic_body_boundary(certificate, artifact_check)
    graph = certificate_dependency_graph(envelope)
    @test graph.payload_kind == :PeriodicBoundaryExtraction
    @test "body.periodic_boundary_extraction" in graph.lean_contracts
    @test "ERIEC.FieldBridge.PeriodicBoundaryWitness" in
        getfield.(graph.lean_dependencies, :full_declaration)
    @test "check_periodic_body_boundary" in graph.julia_checkers
    for edge in (
        (
            from=:PeriodicBoundaryExtraction,
            to="body.periodic_boundary_extraction",
            relation=:lean_contract,
        ),
        (
            from="body.periodic_boundary_extraction",
            to="ERIEC.FieldBridge.PeriodicBoundaryWitness",
            relation=:lean_dependency,
        ),
        (
            from=:PeriodicBoundaryExtraction,
            to="check_periodic_body_boundary",
            relation=:julia_checker,
        ),
    )
        @test edge in graph.edges
        println("G4-BDY-003-EDGE: ", edge)
    end
    @test envelope.claim_scope == :context_local
    @test envelope.trust.execution_layer == :julia_unverified
    @test !envelope.trust.execution_certified
    @test envelope.trust.execution_boundary == :unverified_runtime
    @test_throws ArgumentError certified_artifact_envelope(
        merge(envelope.payload, (lean_contracts=["missing.contract"],)),
        artifact_check,
    )
    @test_throws ArgumentError certified_artifact_envelope(
        merge(envelope.payload, (execution_certified=true,)),
        artifact_check,
    )
    @test_throws ArgumentError ERIEC.certified_periodic_body_boundary(
        missing_certificate,
        artifact_check,
    )
end

@testset "periodic boundary independent finite oracle" begin
    profile = ERIEC.load_sensory_carrier_profile()
    digest = ERIEC.sensory_carrier_profile_sha256()
    for side in 1:3, bits in 0:((1 << (side * side)) - 1)
        support = reshape(
            BitVector(!iszero(bits & (1 << (index - 1))) for index in 1:(side * side)),
            side,
            side,
        )
        # Independent of the extractor/checker's shared _periodic_neighbors.
        boundary = support .& (
            .!circshift(support, (1, 0)) .| .!circshift(support, (-1, 0)) .|
            .!circshift(support, (0, 1)) .| .!circshift(support, (0, -1))
        )
        certificate = ERIEC.PeriodicBoundaryCertificate(
            support, boundary, profile.profile_id, digest,
        )
        # The packet excludes empty masks, including a full torus's empty boundary.
        @test ERIEC.check_periodic_body_boundary(certificate; profile=profile) ==
            (any(support) && any(boundary))
        for index in eachindex(boundary)
            altered = copy(boundary)
            altered[index] = !altered[index]
            invalid = ERIEC.PeriodicBoundaryCertificate(
                support, altered, profile.profile_id, digest,
            )
            @test !ERIEC.check_periodic_body_boundary(invalid; profile=profile)
        end
    end
end

@testset "independent alpha and clamp sigma measurement" begin
    profile = ERIEC.load_sensory_carrier_profile()
    features = [:e1, :e2]
    alpha_trials = [
        ERIEC.PairedInterventionTrial(
            :m1,
            features,
            [0.0, 0.0],
            [1.0, 0.0],
            ERIEC.alpha_trial_provenance((kind=:alpha, action=:m1)),
        ),
        ERIEC.PairedInterventionTrial(
            :m2,
            features,
            [0.0, 0.0],
            [0.0, 1.0],
            ERIEC.alpha_trial_provenance((kind=:alpha, action=:m2)),
        ),
    ]
    clamp_trials = [
        ERIEC.ClampTrial(
            feature,
            action,
            feature == :e1 ? action == :m1 : action == :m2,
            ERIEC.clamp_sigma_trial_provenance(
                (kind=:clamp, feature=feature, action=action),
            ),
        )
        for feature in features for action in (:m1, :m2)
    ]
    alpha = ERIEC.estimate_alpha_relation(alpha_trials; profile=profile)
    sigma = ERIEC.estimate_clamp_sigma_relation(clamp_trials)
    @test ERIEC.alpha_relation_nondegeneracy([:m1, :m2], features, alpha)
    @test ERIEC.check_measured_hconv([:m1, :m2], features, alpha, sigma)

    alpha_provenance = ERIEC.alpha_trial_provenance(alpha_trials)
    sigma_provenance = ERIEC.clamp_sigma_trial_provenance(clamp_trials)
    numeric_assumptions = (
        body_threshold=profile.body_threshold,
        persistence_horizon=profile.persistence_horizon,
        absolute_tolerance=profile.absolute_tolerance,
        relative_tolerance=profile.relative_tolerance,
    )
    certificate = ERIEC.ClampSigmaMeasurementCertificate(
        [:m1, :m2],
        features,
        alpha,
        sigma,
        deepcopy(sigma),
        alpha_provenance,
        sigma_provenance,
        :clamp_identifies_theoretical_sigma_v1,
        profile.profile_id,
        ERIEC.sensory_carrier_profile_sha256(),
        numeric_assumptions,
    )
    checked = ERIEC.check_clamp_sigma_identification(certificate)
    @test checked.ok
    @test checked.hconv
    @test checked.provenance_independent

    flipped_sigma = deepcopy(sigma)
    delete!(flipped_sigma[:e1], :m1)
    sigma_mutant = ERIEC.ClampSigmaMeasurementCertificate(
        certificate.actions,
        certificate.features,
        certificate.alpha_relation,
        flipped_sigma,
        deepcopy(flipped_sigma),
        certificate.alpha_provenance,
        certificate.sigma_provenance,
        certificate.identification_assumption,
        certificate.profile_id,
        certificate.profile_sha256,
        certificate.numeric_assumptions,
    )
    sigma_mutant_check = ERIEC.check_clamp_sigma_identification(sigma_mutant)
    @test sigma_mutant_check.ok
    @test !sigma_mutant_check.hconv
    @test sigma_mutant_check.identifies
    println("FALSIFICATION-BDY-002-SIGMA-FLIP-HCONV-ONLY: PASS")

    flipped_alpha = deepcopy(alpha)
    delete!(flipped_alpha[:m1], :e1)
    alpha_mutant = ERIEC.ClampSigmaMeasurementCertificate(
        certificate.actions,
        certificate.features,
        flipped_alpha,
        certificate.measured_sigma,
        certificate.theoretical_sigma,
        certificate.alpha_provenance,
        certificate.sigma_provenance,
        certificate.identification_assumption,
        certificate.profile_id,
        certificate.profile_sha256,
        certificate.numeric_assumptions,
    )
    alpha_mutant_check = ERIEC.check_clamp_sigma_identification(alpha_mutant)
    @test alpha_mutant_check.ok
    @test !alpha_mutant_check.hconv
    @test alpha_mutant_check.identifies
    println("FALSIFICATION-BDY-002-ALPHA-FLIP-HCONV-ONLY: PASS")

    same_hash = ERIEC.ClampSigmaMeasurementCertificate(
        certificate.actions,
        certificate.features,
        certificate.alpha_relation,
        certificate.measured_sigma,
        certificate.theoretical_sigma,
        certificate.alpha_provenance,
        ERIEC.ClampSigmaTrialProvenance(certificate.alpha_provenance.sha256),
        certificate.identification_assumption,
        certificate.profile_id,
        certificate.profile_sha256,
        certificate.numeric_assumptions,
    )
    same_hash_check = ERIEC.check_clamp_sigma_identification(same_hash)
    @test !same_hash_check.provenance_independent
    @test same_hash_check.complete
    @test same_hash_check.identifies
    @test same_hash_check.hconv
    println("FALSIFICATION-BDY-002-PROVENANCE-ONLY: PASS")

    source = read(joinpath(@__DIR__, "..", "src", "field_bridge.jl"), String)
    sigma_section = split(split(source, "function estimate_clamp_sigma_relation")[2],
        "function alpha_relation_nondegeneracy")[1]
    @test !occursin("estimate_alpha_relation", sigma_section)
    println("FALSIFICATION-BDY-002-INDEPENDENT-DEPENDENCY: PASS")

    artifact_check = verify_lean_certified_artifact()
    envelope = ERIEC.certified_clamp_sigma_identification(certificate, artifact_check)
    graph = certificate_dependency_graph(envelope)
    @test "body.clamp_sigma_identification" in graph.lean_contracts
    @test "check_clamp_sigma_identification" in graph.julia_checkers
end
