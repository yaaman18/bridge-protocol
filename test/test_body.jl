@testset "body" begin
    @testset "mode and kernel separation" begin
        motor = motor_state(collect(1.0:length(intervention_modes())))
        kernel = kernel_param_state([0.15, 0.02, 13.0])

        response = BodyResponse(s -> sensory_state([
            s[normal_push] - s[normal_pull],
            s[tangential_shear],
            s[rotate],
            s[contract] + s[expand],
            s[obstacle_avoidance],
            s[local_growth_up] - s[local_growth_down],
        ]))

        @test body_response_domain_is_intervention(response)
        @test response(motor) isa SensoryState
        @test_throws MethodError response(kernel)
        @test InterventionMode !== KernelParam
    end

    @testset "endogenous response has no external set point" begin
        response = EndogenousBodyResponse(
            s -> sensory_state(fill(s[normal_push], length(sensory_features()))),
            _ -> 1,
        )

        @test endogenous_sigma_defined_without_external_setpoint(response) === response.sigma
        @test body_has_no_external_setpoint(response)
        @test !has_external_setpoint_field(response)
    end

    @testset "no terminal set point diagram" begin
        open_diagram = SetPointDiagram([:seek, :probe], ==)
        @test isempty(terminal_setpoints(open_diagram))
        @test !has_terminal_setpoint(open_diagram)
        @test check_m4_no_terminal_setpoint(open_diagram)

        closed_diagram = SetPointDiagram(
            [:seek, :target],
            (source, candidate) -> source == candidate || candidate == :target,
        )
        @test terminal_setpoints(closed_diagram) == [:target]
        @test has_terminal_setpoint(closed_diagram)
        @test !check_m4_no_terminal_setpoint(closed_diagram)
        @test_throws ArgumentError SetPointDiagram(Symbol[], ==)

        certification = verify_lean_certified_artifact()
        certificate = no_terminal_setpoint_certificate(open_diagram)
        @test certificate.ok
        @test certificate.lean_contracts == ["body.no_terminal_setpoint"]
        certified = certified_no_terminal_setpoint(open_diagram, certification)
        @test certified.payload.kind == :NoTerminalSetPoint
        @test "check_m4_no_terminal_setpoint" in
            certificate_dependency_graph(certified).julia_checkers
        @test occursin(
            "\"kind\":\"NoTerminalSetPoint\"",
            certified_no_terminal_setpoint_json(open_diagram, certification),
        )
        @test !no_terminal_setpoint_certificate(closed_diagram).ok
        @test_throws ArgumentError certified_no_terminal_setpoint(closed_diagram, certification)
    end

    @testset "induced body adjunction" begin
        all_M = Set([normal_push, normal_pull, rotate])
        all_E = Set([boundary_sector, radial_gradient, normal_flux])

        alpha_rel = m -> m == normal_push ? Set([boundary_sector, radial_gradient]) :
                         m == normal_pull ? Set([boundary_sector]) :
                         Set([normal_flux])

        X = Set([boundary_sector, radial_gradient])
        N = Set([normal_push, normal_pull])

        @test body_sigma_star_induced(alpha_rel, all_M, X) ==
              Set([normal_push, normal_pull])
        @test body_galois_conn_induced(alpha_rel, all_M, all_E)
        @test body_unit_induced(alpha_rel, all_M, N)
        @test body_counit_induced(alpha_rel, all_M, X)
    end

    @testset "body Jacobian" begin
        sigma = a -> [
            a[1] + 2a[2],
            sin(a[1]) + a[3]^2,
            a[2] * a[3],
        ]
        a = [0.4, -0.2, 0.7]

        tensor = body_jacobian(sigma, a)
        expected = [
            1.0 2.0 0.0
            cos(a[1]) 0.0 2a[3]
            0.0 a[3] a[2]
        ]

        @test tensor ≈ expected
        @test body_jacobian_adjoint(sigma, a) == transpose(tensor)
        @test check_body_dual_symmetry(sigma, a, [1.0, 0.5, -0.5], [0.25, 1.2, -0.1])

        checks = check_body_tensor_requirements(
            sigma,
            a,
            [1.0, 0.5, -0.5],
            [0.25, 1.2, -0.1],
        )
        @test checks.nonzero_rank
        @test checks.dual_symmetric
        @test checks.nontrivial_loop
        @test checks.loop ≈ transpose(tensor) * tensor
        @test body_loop_operator(sigma, a) ≈ transpose(tensor) * tensor
    end
end
