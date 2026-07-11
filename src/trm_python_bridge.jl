struct TRMPythonBridgeConfig
    python::String
    script::String
    upstream_repo::String
end

function TRMPythonBridgeConfig(;
    python::AbstractString=normpath(joinpath(@__DIR__, "..", ".venv-trm", "bin", "python")),
    script::AbstractString=normpath(joinpath(@__DIR__, "..", "python", "trm_bridge", "bridge.py")),
    upstream_repo::AbstractString=normpath(joinpath(@__DIR__, "..", "external", "TinyRecursiveModels")),
)
    TRMPythonBridgeConfig(String(python), String(script), String(upstream_repo))
end

function trm_python_bridge_available(config::TRMPythonBridgeConfig=TRMPythonBridgeConfig())
    isfile(config.python) && isfile(config.script) &&
        isfile(joinpath(config.upstream_repo, "models", "recursive_reasoning", "trm.py"))
end

function trm_python_bridge_request(
    request::NamedTuple;
    config::TRMPythonBridgeConfig=TRMPythonBridgeConfig(),
)
    trm_python_bridge_available(config) || throw(ArgumentError(
        "TRM Python bridge is not set up; run scripts/setup_trm_python.sh",
    ))
    command = `$(config.python) $(config.script) --repo $(config.upstream_repo)`
    output = read(pipeline(command; stdin=IOBuffer(JSON3.write(request))), String)
    response = try
        JSON3.read(output)
    catch err
        throw(ErrorException("invalid TRM Python bridge response: $(sprint(showerror, err))"))
    end
    haskey(response, :ok) && response.ok === true || throw(ErrorException(
        haskey(response, :error) ? String(response.error) : "TRM Python bridge failed",
    ))
    response
end

trm_python_health(; config::TRMPythonBridgeConfig=TRMPythonBridgeConfig()) =
    trm_python_bridge_request((command=:health,); config=config)

trm_python_smoke(; config::TRMPythonBridgeConfig=TRMPythonBridgeConfig(), seed::Integer=0) =
    trm_python_bridge_request((command=:smoke, seed=Int(seed)); config=config)

function trm_python_infer(
    tokens::AbstractMatrix{<:Integer};
    config::TRMPythonBridgeConfig=TRMPythonBridgeConfig(),
    model_config::NamedTuple=NamedTuple(),
    steps::Integer=3,
    seed::Integer=0,
    checkpoint::Union{AbstractString,Nothing}=nothing,
    puzzle_identifiers=nothing,
)
    size(tokens, 1) > 0 && size(tokens, 2) > 0 ||
        throw(ArgumentError("tokens must be a nonempty matrix"))
    all(>=(0), tokens) || throw(ArgumentError("tokens must be nonnegative"))
    steps >= 1 || throw(ArgumentError("steps must be positive"))
    checkpoint === nothing || isfile(checkpoint) ||
        throw(ArgumentError("TRM checkpoint does not exist: $checkpoint"))
    identifiers = puzzle_identifiers === nothing ? zeros(Int, size(tokens, 1)) :
        Int.(collect(puzzle_identifiers))
    length(identifiers) == size(tokens, 1) ||
        throw(DimensionMismatch("puzzle identifier count must match token batch size"))
    request = (
        command=:infer,
        tokens=[Int.(collect(row)) for row in eachrow(tokens)],
        config=model_config,
        steps=Int(steps),
        seed=Int(seed),
        checkpoint=checkpoint === nothing ? nothing : abspath(checkpoint),
        puzzle_identifiers=identifiers,
    )
    trm_python_bridge_request(request; config=config)
end
