const AUDIT_TARGET_PATTERNS = ((true, true, true, true), (false, true, true, true),
    (true, false, true, true), (true, true, false, true), (true, true, true, false))

_pattern_name(pattern) = pattern == first(AUDIT_TARGET_PATTERNS) ? "all_four" :
    "without_$(DC_FIELDS[only(findall(!, collect(pattern)))])"

function _record_search_case!(counts, found, circuit, case_id)
    measured = measure_circuit(circuit; all_interventions=false)
    measured.result.valid || error("finite checker disagreement")
    key = join(Int.(measured.result.actual))
    counts[key] = get(counts, key, 0) + 1
    pattern = measured.result.actual
    if measured.result.nondegenerate && pattern in AUDIT_TARGET_PATTERNS
        name = _pattern_name(pattern)
        # Preserve first witness; additionally keep the first effective-boundary witness.
        for suffix in ("", "_active_boundary")
            suffix != "" && !measured.active_boundary && continue
            full_name = name * suffix
            if !haskey(found, full_name)
                complete = measure_circuit(circuit)
                complete.result.actual == pattern || error("singleton/full measurement mismatch")
                found[full_name] = (case_id=case_id, measurement=complete)
            end
        end
    end
end

"""Two explicitly bounded exploratory domains. No preregistration candidate is read.
Changing limits creates a different search report, never an assertion of full coverage."""
function search_measured_models(; domain::Symbol=:four_unit_exhaustive, limit=nothing, seed=20260910)
    counts, found = Dict{String,Int}(), Dict{String,Any}()
    if domain == :four_unit_exhaustive
        n, motors = 4, (:u3, :u4)
        total = 32768
    elseif domain == :six_unit_sequence
        n, motors = 6, (:u5, :u6)
        total = 20000
    else
        throw(ArgumentError("unknown search domain"))
    end
    attempts = limit === nothing ? total : _circuit_int(limit)
    0 <= attempts <= total || throw(ArgumentError("limit outside declared domain"))
    seed_value = _circuit_int(seed)
    seed_value >= 0 || throw(ArgumentError("seed must be nonnegative"))
    units = ntuple(i -> Symbol("u$i"), n)
    inputs = (:u1,)
    allowed = [(s, d) for s in 1:n for d in 1:n if s != d && (d != 1 || units[s] in motors)]
    state = UInt64(seed_value)
    draw(k) = begin
        state = state * UInt64(6364136223846793005) + UInt64(1442695040888963407)
        Int((state >> 32) % UInt64(k))
    end
    for case_id in 0:(attempts-1)
        if domain == :four_unit_exhaustive
            graph_mask, initial_mask = divrem(case_id, 16)
            edges = [(s, d, 1) for (i, (s, d)) in enumerate(allowed) if !iszero(graph_mask & (1 << (i-1)))]
            thresholds = ntuple(_ -> 1, n)
        else
            edges = NTuple{3,Int}[]
            for (s, d) in allowed
                w = draw(3)-1
                w == 0 || push!(edges, (s, d, w))
            end
            thresholds = ntuple(_ -> draw(2)+1, n)
            initial_mask = draw(1 << n)
        end
        circuit = AuditCircuit(; units, motors, inputs, edges, thresholds,
            initial=ntuple(i -> !iszero(initial_mask & (1 << (i-1))), n), P=6, H=6, L=4, R=4)
        _record_search_case!(counts, found, circuit, case_id)
    end
    (; domain, attempts, declared_cases=total, seed=seed_value, counts, found,
       exhaustive=domain == :four_unit_exhaustive && attempts == total,
       sequence_completed=attempts == total, phenomenal_claim=:not_certified)
end

function measured_search_report(search)
    witnesses = [merge(circuit_measurement_report(search.found[name].measurement),
        Dict("name" => name, "case_id" => search.found[name].case_id)) for name in sort!(collect(keys(search.found)))]
    Dict("schema_version" => 1, "domain" => String(search.domain), "attempts" => search.attempts,
        "declared_cases" => search.declared_cases, "seed" => search.seed,
        "exhaustive_in_declared_domain" => search.exhaustive, "sequence_completed" => search.sequence_completed,
        "search_stage" => "control_and_singletons", "saved_witness_stage" => "all_subsets",
        "claim" => "exploratory_finite_witnesses", "general_impossibility" => "not_established",
        "phenomenal_claim" => "not_certified", "execution_certified" => false,
        "predicate_order" => String.(collect(DC_FIELDS)), "pattern_counts_including_degenerate" => search.counts,
        "unfound_patterns" => [_pattern_name(p) for p in AUDIT_TARGET_PATTERNS if !haskey(search.found, _pattern_name(p))],
        "witnesses" => witnesses)
end

function verify_search_report(data::AbstractDict)
    all(haskey(data, k) for k in ("domain", "attempts", "seed")) ||
        throw(ArgumentError("missing search input"))
    data["domain"] isa String || throw(ArgumentError("invalid search domain"))
    replay = measured_search_report(search_measured_models(domain=Symbol(data["domain"]),
        limit=data["attempts"], seed=data["seed"]))
    _audit_digest(data) == _audit_digest(replay) || throw(ArgumentError("search replay mismatch"))
    true
end

function measured_witness_corpus()
    data = TOML.parsefile(joinpath(@__DIR__, "fixtures", "measured-witnesses.toml"))
    _exact_keys(data, ("schema_version", "phenomenal_claim", "witnesses"))
    typeof(data["schema_version"]) == Int && data["schema_version"] == 1 &&
        data["phenomenal_claim"] == "not_certified" || throw(ArgumentError("invalid corpus schema"))
    rows = Dict{String,Any}[]
    length(data["witnesses"]) == 5 || throw(ArgumentError("corpus requires five patterns"))
    seen = Set{String}()
    for row in data["witnesses"]
        _exact_keys(row, ("name", "expected", "source_domain", "source_case_id", "circuit"))
        expected = Tuple(row["expected"])
        length(expected) == 4 && all(x -> x isa Bool, expected) && expected in AUDIT_TARGET_PATTERNS ||
            throw(ArgumentError("invalid expected pattern"))
        name = _pattern_name(expected)
        row["name"] == name && name ∉ seen || throw(ArgumentError("duplicate or mislabeled corpus pattern"))
        push!(seen, name)
        measured = measure_circuit(parse_audit_circuit(row["circuit"]))
        measured.result.valid && measured.result.nondegenerate && measured.result.actual == expected ||
            throw(ArgumentError("corpus witness failed its expected pattern"))
        expected[4] && !measured.active_boundary && throw(ArgumentError("corpus boundary is ineffective"))
        push!(rows, merge(circuit_measurement_report(measured), Dict("name" => name,
            "expected" => collect(expected), "source_domain" => row["source_domain"],
            "source_case_id" => row["source_case_id"])))
    end
    Dict("schema_version" => 1, "phenomenal_claim" => "not_certified", "execution_certified" => false,
        "scope" => "measured_dc_separation_corpus", "all_expected_patterns_matched" => true,
        "witnesses" => rows)
end
