function summarize_observation(
    sensory::AbstractVector,
    wld_result::WldResult,
    dc_result::DCResult,
)
    isempty(sensory) && throw(ArgumentError("sensory must be non-empty"))
    sensory_values = Float64.(sensory)
    (
        sensory_summary=(
            min=minimum(sensory_values),
            max=maximum(sensory_values),
            mean=sum(sensory_values) / length(sensory_values),
            length=length(sensory_values),
        ),
        world_summary=(
            nontrivial=world_nontrivial(wld_result),
            eigenvalues=Float64.(wld_result.eigenvalues),
        ),
        dc_summary=(is_dc=is_DC(dc_result),),
    )
end
