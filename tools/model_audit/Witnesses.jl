const DC_FIELDS = (:hSelf, :hSMC, :hAct, :hBound)

function _finite_encoding_valid(model)
    M, E, C = Set(model.M), Set(model.E), Set(model.C)
    all(!isempty, (M, E, C)) || return false
    all(length(getproperty(model, key)) == length(Set(getproperty(model, key)))
        for key in (:M, :E, :C)) || return false
    M ⊆ C && E ⊆ C && isempty(M ∩ E) || return false
    for (relation, domain, codomain) in ((model.alpha, M, E), (model.sigma, E, M),
                                        (model.pi, M, C), (model.rho, C, M),
                                        (model.neighbors, C, C))
        Set(keys(relation)) == domain || return false
        all(Set(image) ⊆ codomain for image in values(relation)) || return false
    end
    model.kappa ⊆ C && model.epsilon ⊆ E
end

"""Compare every DC field; a failed witness must preserve all other expected fields.
This is a finite observation, not certification of measured origin or M1-M4."""
function check_dc_pattern(model, expected::NTuple{4,Bool})
    _finite_encoding_valid(model) ||
        return (valid=false, nondegenerate=false, actual=(), matches=false)
    snapshot = deepcopy(model)
    boundary = Set(c for c in snapshot.kappa
                   if any(d ∉ snapshot.kappa for d in snapshot.neighbors[c]))
    sys = ERIEC.ERIEState{Symbol,Symbol,Symbol,Nothing}(
        m -> copy(snapshot.alpha[m]), e -> copy(snapshot.sigma[e]),
        m -> copy(snapshot.pi[m]), c -> copy(snapshot.rho[c]),
        _ -> copy(snapshot.kappa), _ -> copy(snapshot.epsilon), boundary, nothing)
    result = ERIEC.check_DC(sys)
    actual = Tuple(getproperty(result, field) for field in DC_FIELDS)
    finite_dc = ERIEC.check_DC(sys, snapshot.M, snapshot.E, snapshot.C)
    nondegenerate = !isempty(snapshot.kappa) && snapshot.kappa != Set(snapshot.C) &&
                    !isempty(snapshot.epsilon)
    valid = finite_dc == all(actual)
    (; valid, nondegenerate, actual,
       matches=valid && nondegenerate && actual == expected, boundary, act=copy(result.act))
end

function abstract_dc_models()
    C = (:e1, :e2, :m1, :m2, :c1, :c2)
    base = (M=(:m1, :m2), E=(:e1, :e2), C=C,
        alpha=Dict(:m1 => Set([:e1]), :m2 => Set([:e2])),
        sigma=Dict(:e1 => Set([:m1]), :e2 => Set([:m2])),
        pi=Dict(:m1 => Set([:c1]), :m2 => Set([:c2])),
        rho=Dict(c => c == :c1 ? Set([:m1]) : c == :c2 ? Set([:m2]) : Set{Symbol}() for c in C),
        kappa=Set([:c1]), epsilon=Set([:e1]),
        neighbors=Dict(c => c == :c1 ? Set([:c2]) : Set{Symbol}() for c in C))
    models = [deepcopy(base) for _ in 1:5]
    empty!(models[2].pi[:m1])
    models[3].alpha[:m1] = Set([:e2])
    models[4].sigma[:e1] = Set([:m2])
    models[4].alpha[:m2] = Set([:e1])
    empty!(models[5].neighbors[:c1])
    expected = [(true, true, true, true), (false, true, true, true),
                (true, false, true, true), (true, true, false, true), (true, true, true, false)]
    [(name=i == 1 ? "all_four" : "without_$(DC_FIELDS[i-1])",
      model=models[i], expected=expected[i]) for i in 1:5]
end

function _audit_step(state, edges, thresholds, mask)
    ntuple(length(state)) do target
        total = 0
        for (source, destination, weight) in edges
            if destination == target && iszero(mask & (1 << (source - 1))) && state[source]
                total = Base.Checked.checked_add(total, weight)
            end
        end
        total >= thresholds[target]
    end
end

function _audit_trace(initial, steps, edges, thresholds, mask=0)
    result = [initial]
    for _ in 1:steps
        push!(result, _audit_step(last(result), edges, thresholds, mask))
    end
    result
end

_audit_persist(trace, points, units) = Set(units[i] for i in eachindex(units)
    if all(trace[t][i] for t in (length(trace)-points+1):length(trace)))

"""A separate six-unit witness, never the preregistration candidate.
e -> c -> m -> e maintains the core; a <-> b oscillates; d receives m AND a.
The outward edge m -> d is active, rather than a permanently ineffective boundary."""
function measured_dc_model()
    units = (:e, :c, :m, :a, :b, :d)
    edges = [(3, 1, 1), (1, 2, 1), (2, 3, 1), (5, 4, 1),
             (4, 5, 1), (3, 6, 1), (4, 6, 1)]
    thresholds = (1, 1, 1, 1, 1, 2)
    initial = (true, true, true, true, false, false)
    P, H, L, R = 6, 6, 4, 4
    prefix = _audit_trace(initial, P, edges, thresholds)
    z = last(prefix)
    traces = Dict(mask => _audit_trace(z, H, edges, thresholds, mask) for mask in 0:63)
    baseline = _audit_persist(traces[0], R, units)
    losses = Dict(mask => setdiff(baseline, _audit_persist(t, R, units)) for (mask, t) in traces)
    M, E = (:m,), (:e,)
    kappa = _audit_persist(prefix, L, units)
    epsilon = Set(e for e in E if z[findfirst(==(e), units)])
    singleton(unit) = 1 << (findfirst(==(unit), units) - 1)
    final_changes(source, targets) = Set(target for target in targets if
        last(traces[0])[findfirst(==(target), units)] !=
        last(traces[singleton(source)])[findfirst(==(target), units)])
    model = (M=M, E=E, C=units,
        alpha=Dict(m => final_changes(m, E) for m in M),
        sigma=Dict(e => final_changes(e, M) for e in E),
        pi=Dict(m => copy(losses[singleton(m)]) for m in M),
        rho=Dict(c => intersect(losses[singleton(c)], Set(M)) for c in units),
        kappa=kappa, epsilon=epsilon,
        neighbors=Dict(c => Set(units[d] for (s, d, _) in edges if units[s] == c) for c in units))
    active_boundary = any(edges) do (s, d, _)
        units[s] in kappa && units[d] ∉ kappa &&
            any(traces[0][t][d] != traces[singleton(units[s])][t][d] for t in 2:(H+1))
    end
    (; model, prefix, traces, edges, thresholds, initial, P, H, L, R, active_boundary)
end

"""Return choices fixed by every supplied permutation (or group generator).
Permutation membership is checked; being a symmetry of a physical system is a separate obligation."""
function invariant_choices(candidates::Tuple, permutations)
    isempty(candidates) && throw(ArgumentError("candidate set is empty"))
    length(unique(candidates)) == length(candidates) || throw(ArgumentError("duplicate candidate"))
    n = length(candidates)
    for permutation in permutations
        length(permutation) == n && all(i -> i isa Int, permutation) &&
            sort(collect(permutation)) == collect(1:n) || throw(ArgumentError("invalid permutation"))
    end
    Tuple(candidates[i] for i in 1:n if all(p[i] == i for p in permutations))
end

_audit_names(xs) = sort!(String.(collect(xs)))
function _model_dict(model)
    data = Dict{String,Any}(String(k) => _audit_names(getproperty(model, k))
                           for k in (:M, :E, :C, :kappa, :epsilon))
    for key in (:alpha, :sigma, :pi, :rho, :neighbors)
        data[String(key)] = Dict(String(k) => _audit_names(v) for (k, v) in getproperty(model, key))
    end
    data
end

function model_witness_report()
    rows = Dict{String,Any}[]
    for example in abstract_dc_models()
        result = check_dc_pattern(example.model, example.expected)
        push!(rows, Dict("name" => example.name, "origin" => "abstract_relations",
            "expected" => collect(example.expected), "actual" => collect(result.actual),
            "matched" => result.matches, "nondegenerate" => result.nondegenerate,
            "model" => _model_dict(example.model)))
    end
    measured = measured_dc_model()
    result = check_dc_pattern(measured.model, (true, true, true, true))
    push!(rows, Dict("name" => "source_silencing_six_units", "origin" => "measured_source_silencing",
        "expected" => [true, true, true, true], "actual" => collect(result.actual),
        "matched" => result.matches && measured.active_boundary,
        "nondegenerate" => result.nondegenerate, "active_boundary" => measured.active_boundary,
        "model" => _model_dict(measured.model), "unit_order" => String.(collect(measured.model.C)),
        "edges_one_based" => [collect(edge) for edge in measured.edges],
        "thresholds" => collect(measured.thresholds), "initial" => collect(measured.initial),
        "preparation_steps" => measured.P, "horizon_steps" => measured.H,
        "kappa_points" => measured.L, "effect_points" => measured.R,
        "prefix" => collect.(measured.prefix),
        "traces" => [Dict("source_mask" => mask, "states" => collect.(measured.traces[mask])) for mask in 0:63]))
    Dict("schema_version" => 1, "phenomenal_claim" => "not_certified",
        "execution_certified" => false, "scope" => "finite_model_audit",
        "predicate_order" => String.(collect(DC_FIELDS)),
        "all_expected_patterns_matched" => all(row["matched"] for row in rows),
        "measured_single_failure_rows" => "not_established",
        "symmetry" => Dict("candidates" => ["left", "right"],
            "swap" => [2, 1], "fixed_choices" => collect(invariant_choices(("left", "right"), [(2, 1)]))),
        "witnesses" => rows)
end
