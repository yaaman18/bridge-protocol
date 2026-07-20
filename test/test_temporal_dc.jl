using Test
using ERIEC

@testset "TemporalDC finite boundary audits" begin
    terminating = TemporalDCTrace([true, true, false, false])
    recovering = TemporalDCTrace([true, false, true])
    never_certified = TemporalDCTrace([false, false, false])

    @test check_observed_termination(terminating, [true, true, true, true])
    @test !check_observed_termination(terminating, [true, true, false, true])
    @test !check_observed_termination(terminating, [true, false, true, true])
    @test !check_observed_termination(terminating, [true, true])

    @test check_permanent_termination_prefix(terminating, 2)
    @test !check_permanent_termination_prefix(recovering, 2)
    @test !check_permanent_termination_prefix(never_certified, 2)
    @test_throws ArgumentError check_permanent_termination_prefix(terminating, -1)

    @test check_collapse_trace_termination(4)
    @test_throws ArgumentError check_collapse_trace_termination(0)

    @test check_precarious_prefix(terminating)
    @test !check_precarious_prefix(TemporalDCTrace([true, true, true]))
    @test check_precarious_prefix(never_certified)

    @test check_no_escape_prefix(terminating)
    @test !check_no_escape_prefix(recovering)
    @test check_no_escape_prefix(never_certified)
end
