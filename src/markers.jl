struct FMMarkers
    fm1_global::Bool
    fm2_sensorimotor::Bool
    fm3_self_monitoring::Bool
    fm4_world::Bool
end

fm1_global_participation(with_action_postfixed::Bool, without_action_postfixed::Bool) =
    with_action_postfixed && !without_action_postfixed

function fm2_sensorimotor_integration(
    tensor::AbstractMatrix,
    action_index::Integer;
    tol::Real=1e-10,
    min_channels::Integer=2,
)
    1 <= action_index <= size(tensor, 2) ||
        throw(BoundsError(tensor, (:, action_index)))
    count(abs.(tensor[:, action_index]) .> tol) >= min_channels
end

function fm3_self_monitoring(interoceptive_signal; tol::Real=1e-10)
    if interoceptive_signal isa Bool
        return interoceptive_signal
    end
    if interoceptive_signal isa Number
        return abs(interoceptive_signal) > tol
    end
    any(abs.(interoceptive_signal) .> tol)
end

function fm4_world_participation(
    wld_result::WldResult,
    action_index::Integer;
    tol::Real=1e-10,
)
    projection = world_projection(wld_result)
    1 <= action_index <= size(projection, 2) ||
        throw(BoundsError(projection, (:, action_index)))
    norm(projection[:, action_index]) > tol
end

function classify_action_markers(markers::FMMarkers)
    if markers.fm1_global && markers.fm2_sensorimotor &&
            markers.fm3_self_monitoring && markers.fm4_world
        return :conscious
    end
    if markers.fm1_global && markers.fm4_world &&
            (!markers.fm2_sensorimotor || !markers.fm3_self_monitoring)
        return :blindsight_analog
    end
    :nonconscious
end
