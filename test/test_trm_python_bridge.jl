@testset "official TRM Python bridge" begin
    config = TRMPythonBridgeConfig()
    @test endswith(config.script, joinpath("python", "trm_bridge", "bridge.py"))
    @test_throws ArgumentError trm_python_infer(reshape([-1], 1, 1); config=config)
    @test_throws ArgumentError trm_python_infer(reshape([0], 1, 1); config=config, steps=0)

    if get(ENV, "ERIEC_TEST_TRM_PYTHON", "0") == "1"
        @test trm_python_bridge_available(config)
        health = trm_python_health(; config=config)
        @test health.ok
        @test health.upstream_commit == "c01103738605ba39d1430519b1ee0c62f4c707f8"
        smoke = trm_python_smoke(; config=config, seed=7)
        @test smoke.ok
        @test length(smoke.predictions) == 1
        @test length(smoke.predictions[1]) == 4
        @test smoke.steps == [3]
    end
end
