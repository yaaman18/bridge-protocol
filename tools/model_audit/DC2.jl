# DC2 audit helpers. The DC2 checker itself (`check_dc2` and its helpers) lives in
# tools/ReactivationERIEC/src/dc2_core.jl (RSB-003) and is included here unchanged, so the audit
# checks the code the criterion package binds.
include(joinpath(@__DIR__, "..", "ReactivationERIEC", "src", "dc2_core.jl"))

const DC2_FIELDS = (:hSelf2, :hSMC, :hHingeNeeded, :hUnit)

# The reference models M1–M5 of formal-experiments/M1Refinement.lean §4, transcribed. Each carries
# only the facts Lean proves about it (named after the Lean theorem), so a disagreement with
# `check_dc2` is a disagreement between the Julia transcription and a checked proof.
function _m1r_model(; C, M, E, alpha, sigma, pi, rho)
    S(xs...) = Set{Symbol}(xs)
    (M=Tuple(M), E=Tuple(E), C=Tuple(C),
     alpha=Dict(m => S(alpha[m]...) for m in M), sigma=Dict(e => S(sigma[e]...) for e in E),
     pi=Dict(m => S(pi[m]...) for m in M), rho=Dict(c => S(rho[c]...) for c in C),
     kappa=Set{Symbol}(C), epsilon=Set{Symbol}(E))            # kappa and eps are Set.univ
end

function lean_reference_m1r()
    [
        (name="M1", lean="ERIEC.M1R.M1.dc2, M1.beta_eq, M1.unit_irred",
         model=_m1r_model(C=[:b, :i], M=[:mx, :mi], E=[:e],
            alpha=Dict(:mx => [:e], :mi => []), sigma=Dict(:e => [:mx]),
            pi=Dict(:mx => [:i], :mi => [:b]), rho=Dict(:b => [:mx], :i => [:mi])),
         facts=Dict(:dc2 => true, :beta => Set([:i]), :act => Set([:mx]), :hUnit_v1 => true)),
        (name="M2", lean="ERIEC.M1R.M2.not_self2",
         model=_m1r_model(C=[:a, :b, :w], M=[:m1, :m2], E=[:e],
            alpha=Dict(:m1 => [:e], :m2 => []), sigma=Dict(:e => [:m1]),
            pi=Dict(:m1 => [:b, :w], :m2 => [:a]), rho=Dict(:a => [:m1], :b => [:m2], :w => [])),
         facts=Dict(:hSelf2 => false)),
        (name="M3", lean="ERIEC.M1R.M3.v1_holds, M3.not_hingeNeeded, M3.unitB_irred",
         model=_m1r_model(C=[:a1, :a2, :b1, :b2], M=[:m1, :m2, :n1, :n2], E=[:e],
            alpha=Dict(:m1 => [:e], :m2 => [], :n1 => [], :n2 => []), sigma=Dict(:e => [:m1]),
            pi=Dict(:m1 => [:a2], :m2 => [:a1], :n1 => [:b2], :n2 => [:b1]),
            rho=Dict(:a1 => [:m1], :a2 => [:m2], :b1 => [:n1], :b2 => [:n2])),
         facts=Dict(:hSelf2 => true, :hSMC => true, :hUnit_v1 => true, :hHingeNeeded => false,
                    :act => Set([:m1]), :beta => Set([:a2]), :unit => [:b1, :b2])),
        (name="M4", lean="ERIEC.M1R.M4.not_hingeNeeded",
         model=_m1r_model(C=[:a1, :a2, :b1, :b2], M=[:m1, :m2, :n1, :n2], E=[:e],
            alpha=Dict(:m1 => [:e], :m2 => [], :n1 => [], :n2 => []), sigma=Dict(:e => [:m1]),
            pi=Dict(:m1 => [:a2, :b1], :m2 => [:a1], :n1 => [:b2], :n2 => [:b1]),
            rho=Dict(:a1 => [:m1], :a2 => [:m2], :b1 => [:n1], :b2 => [:n2])),
         facts=Dict(:hHingeNeeded => false)),
        (name="M5", lean="ERIEC.M1R.M5.dc2, M5.beta_eq_kappa, M5.unit_irred",
         model=_m1r_model(C=[:b, :i], M=[:mx, :my], E=[:e],
            alpha=Dict(:mx => [:e], :my => [:e]), sigma=Dict(:e => [:mx, :my]),
            pi=Dict(:mx => [:i], :my => [:b]), rho=Dict(:b => [:mx], :i => [:my])),
         facts=Dict(:dc2 => true, :beta => Set([:b, :i]), :hUnit_v1 => true)),
    ]
end

# A fixed small abstract carrier for exhaustive audit: C = {c1,c2,c3}, M = {m1,m2}, E = {e1}.
# One encoding is 20 bits: alpha 2, sigma 2, pi 6, rho 6, kappa 3, epsilon 1. Relations are set
# by hand here (abstract models), not measured; results over it are "within this carrier" only.
const DC2_CARRIER_C = (:c1, :c2, :c3)
const DC2_CARRIER_M = (:m1, :m2)
const DC2_CARRIER_E = (:e1,)
const DC2_CARRIER_BITS = 20

dc2_carrier_bits(nC, nM, nE) = nM * nE + nE * nM + nM * nC + nC * nM + nC + nE

function dc2_carrier_model(bits::Integer; nC::Integer=3, nM::Integer=2, nE::Integer=1)
    width_total = dc2_carrier_bits(nC, nM, nE)
    0 <= bits < (1 << width_total) || throw(ArgumentError("encoding out of range"))
    b = Int(bits)
    take(width) = (v = b & ((1 << width) - 1); b >>= width; v)
    pick(xs, mask) = Set{Symbol}(xs[i] for i in eachindex(xs) if (mask >> (i - 1)) & 1 == 1)
    C = nC == 3 ? DC2_CARRIER_C : ntuple(i -> Symbol("c$i"), nC)
    M = nM == 2 ? DC2_CARRIER_M : ntuple(i -> Symbol("m$i"), nM)
    E = nE == 1 ? DC2_CARRIER_E : ntuple(i -> Symbol("e$i"), nE)
    alpha = Dict(m => pick(E, take(nE)) for m in M)
    sigma = Dict(e => pick(M, take(nM)) for e in E)
    pi = Dict(m => pick(C, take(nC)) for m in M)
    rho = Dict(c => pick(M, take(nM)) for c in C)
    kappa = pick(C, take(nC))
    epsilon = pick(E, take(nE))
    (; M, E, C, alpha, sigma, pi, rho, kappa, epsilon)
end

const DC2_PATTERNS = (
    (name="all_four", values=(true, true, true, true)),
    (name="without_hSelf2", values=(false, true, true, true)),
    (name="without_hSMC", values=(true, false, true, true)),
    (name="without_hHingeNeeded", values=(true, true, false, true)),
    (name="without_hUnit", values=(true, true, true, false)))

_dc2_pattern_name(d) = begin
    v = (d.hSelf2, d.hSMC, d.hHingeNeeded, d.hUnit)
    i = findfirst(p -> p.values == v, DC2_PATTERNS)
    i === nothing ? nothing : DC2_PATTERNS[i].name
end

"""Nondegeneracy as in `check_dc_pattern`: a nonempty core that is not every constituent, and a
nonempty environment slice."""
dc2_nondegenerate(model) =
    !isempty(model.kappa) && Set(model.kappa) != Set(model.C) && !isempty(model.epsilon)

"""
    dc2_carrier_enumeration() -> NamedTuple

Every encoding of the abstract carrier. Counts per pattern (all and nondegenerate), the first
nondegenerate encoding of each pattern, and the DC2 encodings whose core is every constituent
(for those, any graph boundary is empty, so the graph-boundary hBound is false).
"""
function dc2_carrier_enumeration()
    counts = Dict(p.name => 0 for p in DC2_PATTERNS)
    nondeg = Dict(p.name => 0 for p in DC2_PATTERNS)
    first_nondeg = Dict{String,Int}()
    dc2_true = 0
    dc2_kappa_all = Int[]
    for bits in 0:((1 << DC2_CARRIER_BITS) - 1)
        m = dc2_carrier_model(bits)
        d = check_dc2(m)
        d.valid || continue
        if d.dc2
            dc2_true += 1
            Set(m.kappa) == Set(m.C) && push!(dc2_kappa_all, bits)
        end
        name = _dc2_pattern_name(d)
        name === nothing && continue
        counts[name] += 1
        if dc2_nondegenerate(m)
            nondeg[name] += 1
            haskey(first_nondeg, name) || (first_nondeg[name] = bits)
        end
    end
    (; encodings=1 << DC2_CARRIER_BITS, counts, nondeg, first_nondeg, dc2_true,
       dc2_kappa_all_count=length(dc2_kappa_all), first_dc2_kappa_all=first(dc2_kappa_all))
end

"""
    dc2_measured_search(domain) -> NamedTuple

DC2 on every circuit of a declared search domain (singleton silencing suffices: DC2 reads only
the singleton relations). Also counts how often a nonempty post-fixed core contains a unit that is
post-fixed on its own, which is what keeps non-singleton irreducible units from appearing.
"""
function dc2_measured_search(domain::Symbol; seed=20260910)
    counts = Dict(p.name => 0 for p in DC2_PATTERNS)
    nondeg = Dict(p.name => 0 for p in DC2_PATTERNS)
    first_nondeg = Dict{String,Int}()
    hunit_true = 0
    core_post = 0
    core_post_with_singleton = 0
    walk = for_each_search_circuit(domain, nothing, seed) do circuit, case_id
        m = measure_circuit(circuit; all_interventions=false).model
        d = check_dc2(m)
        d.hUnit && (hunit_true += 1)
        if d.hSelf2 && !isempty(m.kappa)
            core_post += 1
            C = collect(m.C)
            any(c -> _dc2_postfixed(C, m.pi, m.rho, Set([c])), m.kappa) && (core_post_with_singleton += 1)
        end
        name = _dc2_pattern_name(d)
        name === nothing && return
        counts[name] += 1
        if dc2_nondegenerate(m)
            nondeg[name] += 1
            haskey(first_nondeg, name) || (first_nondeg[name] = case_id)
        end
    end
    (; domain, circuits=walk.attempts, exhaustive=domain == :four_unit_exhaustive,
       counts, nondeg, first_nondeg, hunit_true, core_post, core_post_with_singleton)
end

"""
    dc2_carrier_sample(nC, nM, nE; samples, seed) -> Dict(pattern => first nondegenerate encoding)

Deterministic sampling of a carrier too large to enumerate. A pattern missing from the result is
"not found in this sample", not absent from the carrier.
"""
function dc2_carrier_sample(nC::Integer, nM::Integer, nE::Integer; samples::Integer, seed::Integer)
    width = dc2_carrier_bits(nC, nM, nE)
    state = UInt64(seed)
    found = Dict{String,Int}()
    counts = Dict(p.name => 0 for p in DC2_PATTERNS)
    for _ in 1:samples
        state = state * UInt64(6364136223846793005) + UInt64(1442695040888963407)
        bits = Int((state >> 11) & ((UInt64(1) << width) - 1))
        m = dc2_carrier_model(bits; nC, nM, nE)
        dc2_nondegenerate(m) || continue
        d = check_dc2(m)
        d.valid || continue
        name = _dc2_pattern_name(d)
        name === nothing && continue
        counts[name] += 1
        haskey(found, name) || (found[name] = bits)
    end
    (; nC, nM, nE, width, samples, seed, nondeg_counts=counts, first_nondeg=found)
end

"""
    dc2_witness_corpus() -> Dict

The frozen DC2 witnesses (fixtures/dc2-witnesses.toml): abstract carrier encodings, measured
circuits from the declared search domains, and the Lean reference names. Every entry is replayed:
a witness whose recomputed pattern differs from its stored `expected` is rejected.
"""
function dc2_witness_corpus()
    data = TOML.parsefile(joinpath(@__DIR__, "fixtures", "dc2-witnesses.toml"))
    _exact_keys(data, ("schema_version", "phenomenal_claim", "c4_sample", "lean_references", "abstract", "measured"))
    typeof(data["schema_version"]) == Int && data["schema_version"] == 1 &&
        data["phenomenal_claim"] == "not_certified" || throw(ArgumentError("invalid DC2 corpus schema"))
    data["lean_references"] == [m.name for m in lean_reference_m1r()] ||
        throw(ArgumentError("DC2 corpus names Lean references that are not transcribed"))
    for row in data["abstract"]
        m = dc2_carrier_model(row["encoding"]; nC=row["nC"], nM=row["nM"], nE=row["nE"])
        d = check_dc2(m)
        d.valid && collect((d.hSelf2, d.hSMC, d.hHingeNeeded, d.hUnit)) == row["expected"] ||
            throw(ArgumentError("abstract DC2 witness $(row["name"]) does not replay"))
    end
    for row in data["measured"]
        d = check_dc2(measure_circuit(parse_audit_circuit(row["circuit"]); all_interventions=false).model)
        collect((d.hSelf2, d.hSMC, d.hHingeNeeded, d.hUnit)) == row["expected"] ||
            throw(ArgumentError("measured DC2 witness $(row["name"]) does not replay"))
    end
    data
end

"""Serializable form of a DC2 model whose carriers need not overlap (no graph)."""
function dc2_model_dict(model)
    data = Dict{String,Any}(String(k) => _audit_names(getproperty(model, k))
                           for k in (:M, :E, :C, :kappa, :epsilon))
    for key in (:alpha, :sigma, :pi, :rho)
        data[String(key)] = Dict(String(k) => _audit_names(v) for (k, v) in getproperty(model, key))
    end
    data
end
