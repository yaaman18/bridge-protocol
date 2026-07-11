const K1_FORBIDDEN_EXTERNAL_SETPOINT_TERMS = (
    "external_setpoint",
    "target_pattern",
    "ExternalSetPoint",
)

function _julia_source_files(src_dir)
    isdir(src_dir) || throw(ArgumentError("src_dir is not a directory: $src_dir"))
    sort!(
        [
            joinpath(root, file)
            for (root, _, files) in walkdir(src_dir)
            for file in files
            if endswith(file, ".jl")
        ],
    )
end

function _is_k1_guardrail_file(path)
    basename(path) in ("body.jl", "checkpoints.jl", "ERIEC.jl")
end

function forbidden_external_setpoint_terms(paths; terms=K1_FORBIDDEN_EXTERNAL_SETPOINT_TERMS)
    matches = NamedTuple[]
    for path in paths
        for (line_number, line) in enumerate(eachline(path))
            for term in terms
                occursin(term, line) || continue
                push!(matches, (path=path, line=line_number, term=term, text=line))
            end
        end
    end
    matches
end

function check_K1(; src_dir=joinpath(@__DIR__))
    files = filter(!(_is_k1_guardrail_file), _julia_source_files(src_dir))
    isempty(forbidden_external_setpoint_terms(files)) &&
        body_has_no_external_setpoint(BodyResponse(identity)) &&
        body_has_no_external_setpoint(EndogenousBodyResponse(identity, identity))
end

check_K1_endogenous_response(response::EndogenousBodyResponse) =
    body_has_no_external_setpoint(response)

check_K1_endogenous_response(_) = false

function check_K1_structural(
    response;
    src_dir=joinpath(@__DIR__),
    setpoint_diagram::Union{SetPointDiagram,Nothing}=nothing,
)
    files = filter(!(_is_k1_guardrail_file), _julia_source_files(src_dir))
    isempty(forbidden_external_setpoint_terms(files)) &&
        check_K1_endogenous_response(response) &&
        (setpoint_diagram === nothing || check_m4_no_terminal_setpoint(setpoint_diagram))
end
