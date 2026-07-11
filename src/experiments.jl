struct SystemSeriesResult
    results::Vector{SystemPipelineResult}
    slowing::NamedTuple
    classifications::Vector{Union{Symbol,Nothing}}
end

function run_system_series(
    adapter::SigmaSystemAdapter,
    actions,
    dc_result::DCResult;
    kwargs...,
)
    results = [
        run_system_pipeline(adapter, action, dc_result; kwargs...)
        for action in actions
    ]
    slowing = critical_slowing_series([result.wld_result for result in results])
    classifications = [result.classification for result in results]
    SystemSeriesResult(results, slowing, classifications)
end
