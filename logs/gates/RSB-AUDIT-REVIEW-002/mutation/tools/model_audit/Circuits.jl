_circuit_int(x) = x isa Integer && !(x isa Bool) && typemin(Int64) <= x <= typemax(Int64) ?
    Int64(x) : throw(ArgumentError("expected an Int64 integer (not Bool)"))

const MAX_AUDIT_UNITS = 12

"""Immutable, bounded input for an observational experiment, not a certified system."""
struct AuditCircuit
    units::Tuple{Vararg{Symbol}}
    motors::Tuple{Vararg{Symbol}}
    inputs::Tuple{Vararg{Symbol}}
    edges::Tuple{Vararg{NTuple{3,Int64}}}
    thresholds::Tuple{Vararg{Int64}}
    initial::Tuple{Vararg{Bool}}
    P::Int64
    H::Int64
    L::Int64
    R::Int64
    function AuditCircuit(; units, motors, inputs, edges, thresholds, initial, P, H, L, R)
        names(xs) = Tuple(Symbol(x) for x in _audit_strings(String.(collect(xs))))
        C, M, E = names(units), names(motors), names(inputs)
        n = length(C)
        2 <= n <= MAX_AUDIT_UNITS || throw(ArgumentError("audit interpreter supports 2..$MAX_AUDIT_UNITS units"))
        !isempty(M) && !isempty(E) && Set(M) ⊆ Set(C) && Set(E) ⊆ Set(C) &&
            isempty(Set(M) ∩ Set(E)) || throw(ArgumentError("invalid or overlapping roles"))
        theta = Tuple(_circuit_int(x) for x in thresholds)
        length(theta) == n && all(>(0), theta) || throw(ArgumentError("invalid positive thresholds"))
        x0 = Tuple(initial)
        length(x0) == n && all(x -> x isa Bool, x0) || throw(ArgumentError("initial state must be Boolean"))
        edge_values = NTuple{3,Int64}[]
        seen = Set{Tuple{Int64,Int64}}()
        for edge in edges
            length(edge) == 3 || throw(ArgumentError("an edge needs source, destination, weight"))
            s, d, w = Tuple(_circuit_int(x) for x in edge)
            1 <= s <= n && 1 <= d <= n && s != d && w != 0 || throw(ArgumentError("invalid edge"))
            (s, d) ∉ seen || throw(ArgumentError("duplicate edge"))
            C[d] ∉ E || C[s] in M || throw(ArgumentError("input edges must come from motors"))
            push!(seen, (s, d))
            push!(edge_values, (s, d, w))
        end
        for d in 1:n
            sum((abs(BigInt(w)) for (_, target, w) in edge_values if target == d); init=big(0)) <=
                typemax(Int64) || throw(ArgumentError("incoming absolute sum can overflow Int64"))
        end
        p, h, l, r = _circuit_int.((P, H, L, R))
        0 <= p <= 256 && 1 <= h <= 256 && 1 <= l <= p + 1 && 1 <= r <= h ||
            throw(ArgumentError("invalid windows (P/H limited to 256 by the audit tool)"))
        new(C, M, E, Tuple(sort!(edge_values)), theta, x0, p, h, l, r)
    end
end

function circuit_dict(c::AuditCircuit)
    Dict("schema_version" => 1, "units" => String.(collect(c.units)),
        "motors" => String.(collect(c.motors)), "inputs" => String.(collect(c.inputs)),
        "edges" => collect.(collect(c.edges)), "thresholds" => collect(c.thresholds),
        "initial" => collect(c.initial), "P" => c.P, "H" => c.H, "L" => c.L, "R" => c.R)
end

function parse_audit_circuit(data::AbstractDict)
    _exact_keys(data, ("schema_version", "units", "motors", "inputs", "edges", "thresholds", "initial", "P", "H", "L", "R"))
    typeof(data["schema_version"]) == Int && data["schema_version"] == 1 ||
        throw(ArgumentError("unsupported circuit schema"))
    for key in ("units", "motors", "inputs")
        _audit_strings(data[key])
    end
    AuditCircuit(; (Symbol(k) => v for (k, v) in data if k != "schema_version")...)
end

"""Require a complete Boolean lattice; signed networks need all proper subsets."""
function minimal_loss_masks(losses, target, n::Integer)
    1 <= n <= MAX_AUDIT_UNITS || throw(ArgumentError("invalid lattice size"))
    Set(keys(losses)) == Set(0:((1 << n)-1)) || throw(ArgumentError("incomplete intervention lattice"))
    minima = Int[]
    for mask in 0:((1 << n)-1)
        target in losses[mask] || continue
        sub = mask
        minimal = true
        while sub != 0
            sub = (sub - 1) & mask
            if target in losses[sub]
                minimal = false
                break
            end
        end
        minimal && push!(minima, mask)
    end
    Tuple(minima)
end

function measure_circuit(c::AuditCircuit; all_interventions::Bool=true)
    units, n = c.units, length(c.units)
    prefix = _audit_trace(c.initial, c.P, c.edges, c.thresholds)
    anchor = last(prefix)
    masks = all_interventions ? collect(0:((1 << n)-1)) : [0; [1 << (i-1) for i in 1:n]]
    traces = Dict(mask => _audit_trace(anchor, c.H, c.edges, c.thresholds, mask) for mask in masks)
    baseline = _audit_persist(traces[0], c.R, units)
    losses = Dict(mask => setdiff(baseline, _audit_persist(t, c.R, units)) for (mask, t) in traces)
    singleton(unit) = 1 << (findfirst(==(unit), units)-1)
    changed(source, targets) = Set(target for target in targets if
        last(traces[0])[findfirst(==(target), units)] != last(traces[singleton(source)])[findfirst(==(target), units)])
    kappa = _audit_persist(prefix, c.L, units)
    model = (M=c.motors, E=c.inputs, C=units,
        alpha=Dict(m => changed(m, c.inputs) for m in c.motors),
        sigma=Dict(e => changed(e, c.motors) for e in c.inputs),
        pi=Dict(m => copy(losses[singleton(m)]) for m in c.motors),
        rho=Dict(u => intersect(losses[singleton(u)], Set(c.motors)) for u in units),
        kappa=kappa, epsilon=Set(e for e in c.inputs if anchor[findfirst(==(e), units)]),
        neighbors=Dict(u => Set(units[d] for (s, d, _) in c.edges if units[s] == u) for u in units))
    result = check_dc_pattern(model, (true, true, true, true))
    active_boundary = any(c.edges) do (s, d, _)
        units[s] in kappa && units[d] ∉ kappa &&
            any(traces[0][t][d] != traces[1 << (s-1)][t][d] for t in 2:(c.H+1))
    end
    minima = all_interventions ? Dict(u => minimal_loss_masks(losses, u, n) for u in units) : nothing
    collective = all_interventions ? Set(u for u in units if !isempty(minima[u]) &&
        all(u ∉ losses[1 << (i-1)] for i in 1:n)) : nothing
    (; circuit=c, prefix, anchor, traces, baseline, losses, model, result, active_boundary,
       all_interventions, minima, collective, phenomenal_claim=:not_certified)
end

function circuit_measurement_report(measured)
    c = measured.circuit
    data = Dict{String,Any}("schema_version" => 1, "circuit" => circuit_dict(c),
        "circuit_digest" => _audit_digest(circuit_dict(c)), "origin" => "measured_source_silencing",
        "all_interventions" => measured.all_interventions, "predicate_order" => String.(collect(DC_FIELDS)),
        "actual" => collect(measured.result.actual), "nondegenerate" => measured.result.nondegenerate,
        "valid" => measured.result.valid, "active_boundary" => measured.active_boundary,
        "phenomenal_claim" => "not_certified", "execution_certified" => false,
        "model" => _model_dict(measured.model), "prefix" => collect.(measured.prefix),
        "traces" => [Dict("source_mask" => mask, "states" => collect.(measured.traces[mask]),
                          "losses" => _audit_names(measured.losses[mask])) for mask in sort!(collect(keys(measured.traces)))])
    if measured.all_interventions
        data["minimal_loss_masks"] = Dict(String(k) => collect(v) for (k, v) in measured.minima)
        data["collective_only_loss"] = _audit_names(measured.collective)
    end
    data
end

"""Recompute all reported values; a stored digest or verdict is not an authority."""
function verify_measurement_report(data::AbstractDict)
    haskey(data, "circuit") && haskey(data, "all_interventions") ||
        throw(ArgumentError("missing measurement input"))
    data["all_interventions"] isa Bool || throw(ArgumentError("invalid intervention coverage flag"))
    circuit = parse_audit_circuit(data["circuit"])
    replay = circuit_measurement_report(measure_circuit(circuit; all_interventions=data["all_interventions"]))
    _audit_digest(data) == _audit_digest(replay) || throw(ArgumentError("measurement replay mismatch"))
    true
end
