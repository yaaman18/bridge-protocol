# Planted-structure ground truth for DC2's hUnit (specs/packets/DC2-GROUND-TRUTH-001.md).
# The labels G and planted_loops come from the design of each template
# (fixtures/organization-ground-truth.toml), never from a measurement.

const GROUND_TRUTH_FIXTURE = joinpath(@__DIR__, "fixtures", "organization-ground-truth.toml")
# v2: user decisions of 2026-10-02 (specs/packets/DC2-GROUND-TRUTH-002.md). A planted loop must contain
# a motor, and must carry the persistence of every one of its members.
const GROUND_TRUTH_FIXTURE_V2 = joinpath(@__DIR__, "fixtures", "organization-ground-truth-v2.toml")
_ground_truth_fixture(version) = version == 1 ? GROUND_TRUTH_FIXTURE :
    version == 2 ? GROUND_TRUTH_FIXTURE_V2 : throw(ArgumentError("unknown ground-truth version"))
const GROUND_TRUTH_KEYS = ("name", "G", "planted_loops", "designed_kappa", "units", "motors",
                           "edges", "thresholds", "initial")

function organization_templates(version::Integer=1)
    data = TOML.parsefile(_ground_truth_fixture(version))
    _exact_keys(data, ("schema_version", "phenomenal_claim", "template"))
    data["schema_version"] == 1 && data["phenomenal_claim"] == "not_certified" ||
        throw(ArgumentError("invalid ground-truth schema"))
    for t in data["template"]
        _exact_keys(t, GROUND_TRUTH_KEYS)
        t["G"] == !isempty(t["planted_loops"]) ||
            throw(ArgumentError("template $(t["name"]): G must be true exactly when a loop is planted"))
        all(loop -> length(unique(loop)) >= 2 && loop ⊆ t["designed_kappa"], t["planted_loops"]) ||
            throw(ArgumentError("template $(t["name"]): a planted loop needs two persisting units"))
        version == 2 && !all(loop -> !isdisjoint(loop, t["motors"]), t["planted_loops"]) &&
            throw(ArgumentError("template $(t["name"]): a v2 planted loop needs a motor"))
    end
    allunique(t["name"] for t in data["template"]) || throw(ArgumentError("duplicate template name"))
    data["template"]
end

"""
    template_circuit(t, perm) -> AuditCircuit

Position i of the built circuit holds unit `perm[i]` of the template. The permutation changes only
the order of units, never which units are connected.
"""
function template_circuit(t, perm=1:length(t["units"]))
    n = length(t["units"])
    sort(collect(perm)) == 1:n || throw(ArgumentError("not a permutation"))
    where = invperm(collect(perm))
    AuditCircuit(units=t["units"][perm], motors=t["motors"], inputs=["in"],
        edges=[[where[s], where[d], w] for (s, d, w) in t["edges"]],
        thresholds=t["thresholds"][perm], initial=t["initial"][perm], P=6, H=6, L=4, R=4)
end

"""Deterministic orders checked for every template: identity, reversed, rotated by one."""
template_orders(n) = (collect(1:n), collect(n:-1:1), [collect(2:n); 1])

function evaluate_template(t, perm)
    measured = measure_circuit(template_circuit(t, perm); all_interventions=false)
    kappa = Set(String.(collect(measured.model.kappa)))
    design_ok = kappa == Set(t["designed_kappa"])
    d = check_dc2(measured.model)
    pairs = [sort(String.(p)) for p in d.mutual_pairs]
    loops = [Set(loop) for loop in t["planted_loops"]]
    unsound = [p for p in pairs if !any(loop -> Set(p) ⊆ loop, loops)]
    # Pair-level completeness, added on 2026-10-02 after the first run showed a planted loop with
    # no pair (two-loops-one-way). It reads the frozen labels; it does not change them.
    undetected = [sort(collect(loop)) for loop in loops if !any(p -> Set(p) ⊆ loop, pairs)]
    G = t["G"]
    outcome = !design_ok ? "design_error" :
              d.hUnit == G ? (G ? "true_positive" : "true_negative") :
              d.hUnit ? "false_positive" : "false_negative"
    (; name=t["name"], G, design_ok, kappa=sort!(collect(kappa)), hUnit=d.hUnit, hUnit_v1=d.hUnit_v1,
       hSelf2=d.hSelf2, pairs=sort!(pairs), unsound_pairs=sort!(unsound),
       undetected_loops=sort!(undetected), outcome,
       outcome_v1=!design_ok ? "design_error" :
                  d.hUnit_v1 == G ? (G ? "true_positive" : "true_negative") :
                  d.hUnit_v1 ? "false_positive" : "false_negative")
end

function ground_truth_report(version::Integer=1)
    rows = Dict{String,Any}[]
    for t in organization_templates(version)
        results = [evaluate_template(t, perm) for perm in template_orders(length(t["units"]))]
        r = first(results)
        strip(x) = (x.design_ok, x.hUnit, x.hUnit_v1, x.pairs, x.outcome)
        push!(rows, Dict{String,Any}("name"=>r.name, "G"=>r.G, "design_ok"=>r.design_ok,
            "kappa"=>r.kappa, "hSelf2"=>r.hSelf2, "hUnit"=>r.hUnit, "hUnit_v1"=>r.hUnit_v1,
            "mutual_pairs"=>r.pairs, "unsound_pairs"=>r.unsound_pairs,
            "undetected_planted_loops"=>r.undetected_loops,
            "outcome"=>r.outcome, "outcome_v1"=>r.outcome_v1,
            "order_invariant"=>all(x -> strip(x) == strip(r), results)))
    end
    tally(key) = Dict(o => count(r -> r[key] == o, rows) for o in
        ("true_positive", "true_negative", "false_positive", "false_negative", "design_error"))
    Dict{String,Any}("schema_version"=>1, "ground_truth_version"=>version,
        "fixture_sha256"=>bytes2hex(open(sha256, _ground_truth_fixture(version))),
        "templates"=>rows, "outcomes"=>tally("outcome"), "outcomes_v1"=>tally("outcome_v1"),
        "unsound_pair_count"=>sum(length(r["unsound_pairs"]) for r in rows),
        "planted_loop_count"=>sum(length(t["planted_loops"]) for t in organization_templates(version)),
        "undetected_planted_loop_count"=>sum(length(r["undetected_planted_loops"]) for r in rows),
        "all_order_invariant"=>all(r -> r["order_invariant"], rows),
        "claim"=>"agreement_with_planted_design_labels_not_with_real_systems",
        "phenomenal_claim"=>"not_certified")
end

# Mechanism-level organization (false-negative check, 2026-10-02). A different intervention from the
# measurement: the measurement silences a unit's outputs; this removes the edges of one directed
# cycle (same anchor, horizon H and window R as the measurement).
#
# Cycles range over every unit and must contain at least two core units (κ), because N3's pairs lie
# in κ. Earlier versions took cycles inside κ only, then inside the units persisting after the
# anchor; both missed real dependence through units that switched on too late to be in κ
# (four_unit_exhaustive case 5434) or that oscillate (six_unit_sequence case 4652).
#
# Cycles use excitatory edges (positive weight) only: persistence is supported by excitatory input,
# and removing an inhibitory edge breaks persistence by releasing inhibition, not by cutting a
# support loop (six_unit_sequence case 2564).
#
# Known limitation: removing one cycle's edges also breaks every other cycle that shares an edge, so
# a cycle can be credited with persistence that another cycle carries (four_unit_exhaustive case 5490).
#
# Two readings of "the cycle carries persistence", both reported:
# - weak: removing the cycle's edges makes SOME member stop persisting;
# - strict: removing the cycle's edges makes EVERY member stop persisting.
# The weak reading also counts a follower whose edge back to its source is redundant
# (six_unit_sequence case 6405).

function _simple_cycles(nodes, edges)
    succ = Dict(v => sort!([d for (s, d, w) in edges if s == v && d in nodes && w > 0]) for v in nodes)
    cycles = Vector{Vector{Int}}()
    for start in sort(collect(nodes))
        stack = [(start, [start])]
        while !isempty(stack)
            v, path = pop!(stack)
            for w in succ[v]
                if w == start && length(path) >= 2
                    push!(cycles, copy(path))
                elseif w > start && w ∉ path
                    push!(stack, (w, [path; w]))
                end
            end
        end
    end
    cycles
end

"""
    mechanism_organization(circuit) -> NamedTuple

`weak_cycles` / `strict_cycles` list the carrying cycles under each reading; `G_weak` / `G_strict`
are true iff there is one.
"""
function mechanism_organization(c::AuditCircuit)
    units = c.units
    prefix = _audit_trace(c.initial, c.P, c.edges, c.thresholds)
    anchor = last(prefix)
    kappa = _audit_persist(prefix, c.L, units)
    baseline = _audit_persist(_audit_trace(anchor, c.H, c.edges, c.thresholds), c.R, units)
    nodes = Set(eachindex(units))
    weak = Vector{Vector{Symbol}}()
    strict = Vector{Vector{Symbol}}()
    for z in _simple_cycles(nodes, c.edges)
        count(i -> units[i] in kappa, z) >= 2 || continue
        cut = Set((z[i], z[mod1(i + 1, length(z))]) for i in eachindex(z))
        kept = Tuple(e for e in c.edges if (e[1], e[2]) ∉ cut)
        after = _audit_persist(_audit_trace(anchor, c.H, kept, c.thresholds), c.R, units)
        lost = [units[i] ∉ after for i in z]
        any(lost) && push!(weak, collect(units[z]))
        all(lost) && push!(strict, collect(units[z]))
    end
    # v2 organization (user decisions of 2026-10-02): an excitatory cycle with a motor whose every edge
    # is needed: removing the single edge p → z makes z stop persisting (no member has another
    # sufficient source). Removing one edge at a time avoids crediting a cycle with what another cycle
    # sharing an edge carries (four_unit_exhaustive case 1713).
    organization = Vector{Vector{Symbol}}()
    for z in _simple_cycles(nodes, c.edges)
        count(i -> units[i] in kappa, z) >= 2 && any(i -> units[i] in c.motors, z) || continue
        needed = all(eachindex(z)) do k
            p, q = z[k], z[mod1(k + 1, length(z))]
            kept = Tuple(e for e in c.edges if (e[1], e[2]) != (p, q))
            units[q] in baseline &&
                units[q] ∉ _audit_persist(_audit_trace(anchor, c.H, kept, c.thresholds), c.R, units)
        end
        needed && push!(organization, collect(units[z]))
    end
    (; G_weak=!isempty(weak), G_strict=!isempty(strict), G_org=!isempty(organization),
       weak_cycles=weak, strict_cycles=strict, organization_cycles=organization, kappa, baseline)
end

"""Groups of units joined by carrying cycles that share a unit (connected components). Two units
depend on each other through a hub without lying on one simple cycle (six_unit_sequence case 39)."""
function cycle_components(cycles)
    groups = [Set(z) for z in cycles]
    merged = true
    while merged
        merged = false
        for i in eachindex(groups), j in (i + 1):length(groups)
            if !isdisjoint(groups[i], groups[j])
                union!(groups[i], groups[j]); deleteat!(groups, j); merged = true
                break
            end
        end
        merged && continue
    end
    groups
end

"""
    unit_organization(circuit) -> NamedTuple

v3 mechanism truth (specs/packets/DC2-GROUND-TRUTH-003.md, user decisions of 2026-10-02): an
excitatory simple cycle with at least two core units and a motor, in which silencing each unit p
makes its successor z on the cycle stop persisting (no part-level redundancy).
"""
function unit_organization(c::AuditCircuit)
    units = c.units
    prefix = _audit_trace(c.initial, c.P, c.edges, c.thresholds)
    anchor = last(prefix)
    kappa = _audit_persist(prefix, c.L, units)
    baseline = _audit_persist(_audit_trace(anchor, c.H, c.edges, c.thresholds), c.R, units)
    lost(p) = setdiff(baseline, _audit_persist(_audit_trace(anchor, c.H, c.edges, c.thresholds, 1 << (p - 1)), c.R, units))
    losses = Dict(p => lost(p) for p in eachindex(units))
    cycles = Vector{Vector{Symbol}}()
    for z in _simple_cycles(Set(eachindex(units)), c.edges)
        count(i -> units[i] in kappa, z) >= 2 && any(i -> units[i] in c.motors, z) || continue
        all(k -> units[z[mod1(k + 1, length(z))]] in losses[z[k]], eachindex(z)) &&
            push!(cycles, collect(units[z]))
    end
    (; G=!isempty(cycles), cycles, kappa, baseline)
end

"""
    motor_action_variant(measured) -> model

Trial reading for decision (D), never the default. The measurement reads ρ(c) = loss(c) ∩ M: the
actions lost when c is silenced are the motors that stop persisting. In this variant, silencing a
motor a also removes a's own action whenever a persists at baseline, even if the unit a stays on:
ρ'(c) = (loss(c) ∩ M) ∪ ({c} ∩ M ∩ baseline). π, κ, ε, α, σ are unchanged.
"""
function motor_action_variant(measured)
    m = measured.model
    rho = Dict(u => (u in m.M && u in measured.baseline) ? union(m.rho[u], Set([u])) : copy(m.rho[u])
               for u in keys(m.rho))
    merge(m, (; rho))
end

"""
    motor_self_production_variant(measured) -> model

Second trial reading, added after (D) left every hUnit verdict unchanged; never the default. The
measurement reads π(a) = loss(a): a motor unit counts as produced by its own action only if it stops
persisting when its outputs are silenced. Here an active motor's action also counts as producing the
motor unit itself: π''(a) = loss(a) ∪ ({a} ∩ baseline). ρ is the (D) reading ρ'. κ, ε, α, σ unchanged.
"""
function motor_self_production_variant(measured)
    m = motor_action_variant(measured)
    pi = Dict(a => (a in measured.baseline) ? union(m.pi[a], Set([a])) : copy(m.pi[a]) for a in keys(m.pi))
    merge(m, (; pi))
end

"""
    pair_organization(circuit) -> NamedTuple

v4 mechanism truth (specs/packets/DC2-GROUND-TRUTH-004.md, user decision of 2026-10-04): pairs
c ≠ d of κ with d ∈ loss(c) and c ∈ loss(d) (single silencing, mutual irreplaceability judged at the
two ends only), whose dependence passes through a motor on one of its two legs.
"""
function pair_organization(c::AuditCircuit)
    units = c.units
    n = length(units)
    prefix = _audit_trace(c.initial, c.P, c.edges, c.thresholds)
    anchor = last(prefix)
    kappa = _audit_persist(prefix, c.L, units)
    baseline = _audit_persist(_audit_trace(anchor, c.H, c.edges, c.thresholds), c.R, units)
    loss = [setdiff(baseline, _audit_persist(_audit_trace(anchor, c.H, c.edges, c.thresholds, 1 << (i - 1)), c.R, units))
            for i in 1:n]
    # reachability over every nonzero edge
    reach = [falses(n) for _ in 1:n]
    for i in 1:n
        stack = [i]
        while !isempty(stack)
            v = pop!(stack)
            for (s, d, _) in c.edges
                s == v && !reach[i][d] && (reach[i][d] = true; push!(stack, d))
            end
        end
    end
    same_scc(i, j) = i == j || (reach[i][j] && reach[j][i])
    motors = [i for i in 1:n if units[i] in c.motors]
    core = sort!([i for i in 1:n if units[i] in kappa])
    pairs = Vector{Vector{Symbol}}()
    for (k, i) in enumerate(core), j in core[(k + 1):end]
        units[j] in loss[i] && units[i] in loss[j] || continue
        # Condition 2 (corrected 2026-10-04): the dependence itself passes through a motor a, i.e. a lies
        # on one leg of the mutual dependence: silencing one end loses a (or a is that end) and silencing
        # a loses the other end (or a is that end). The first version only asked that a motor share the
        # strongly connected component, which also admitted motors that merely follow the pair, drive it
        # from outside, or connect only through inhibitory edges (logs/gates/DC2-GT4-20261004/).
        on_leg(a, from, to) = (a == from || units[a] in loss[from]) && (a == to || units[to] in loss[a])
        any(a -> on_leg(a, i, j) || on_leg(a, j, i), motors) && push!(pairs, sort!([units[i], units[j]]))
    end
    (; G=!isempty(pairs), pairs, kappa, baseline)
end

# Known differences between N3 and the v4 truth (fixtures/dc2-known-differences.toml, user decision
# of 2026-10-04). Accepted classes are counted; pending classes and unclassified differences are
# reported to the user (specs/packets/DC2-HUNIT-N3.md, N3-RETRACT-UNINFORMATIVE).

const KNOWN_DIFFERENCES_FIXTURE = joinpath(@__DIR__, "fixtures", "dc2-known-differences.toml")
const _KNOWN_DIFFERENCE_RULES = Dict(
    # some member of the pair is a motor a with a ∉ loss(a)
    "D_MOTOR_NOT_SELF_LOST" => (pair, motors, loss) -> any(a -> a in pair && a ∉ loss(a), motors),
    # exactly one N3 direction holds: x ∈ Φ({y}) iff some a ∈ loss(y) ∩ M has x ∈ loss(a)
    "ONE_LEG_ACTION" => (pair, motors, loss) -> begin
        x, y = pair
        dir(x, y) = any(a -> a in loss(y) && x in loss(a), motors)
        dir(x, y) != dir(y, x)
    end,
    # an end is not lost when the other end is silenced
    "N3_LOSS_COMPOSITION_EXTRA" => (pair, motors, loss) -> begin
        x, y = pair
        !(x in loss(y) && y in loss(x))
    end)

function known_differences()
    data = TOML.parsefile(KNOWN_DIFFERENCES_FIXTURE)
    _exact_keys(data, ("schema_version", "phenomenal_claim", "class"))
    data["schema_version"] == 1 && data["phenomenal_claim"] == "not_certified" ||
        throw(ArgumentError("invalid known-difference schema"))
    for c in data["class"]
        _exact_keys(c, ("id", "kind", "status", "decided", "meaning", "rule"))
        haskey(_KNOWN_DIFFERENCE_RULES, c["id"]) || throw(ArgumentError("no rule for class $(c["id"])"))
        c["kind"] in ("pair_missed_by_N3", "pair_extra_in_N3") || throw(ArgumentError("unknown kind"))
        c["status"] in ("accepted", "pending") || throw(ArgumentError("unknown status"))
        c["status"] == "accepted" && isempty(c["decided"]) && throw(ArgumentError("accepted class needs a decision date"))
    end
    data["class"]
end

"""Class id of one difference, or "UNCLASSIFIED". `kind` is "pair_missed_by_N3" or "pair_extra_in_N3"."""
function classify_difference(kind, pair, motors, loss, classes=known_differences())
    for c in classes
        c["kind"] == kind && _KNOWN_DIFFERENCE_RULES[c["id"]](pair, motors, loss) && return c["id"]
    end
    "UNCLASSIFIED"
end

"""
    known_difference_report(domains) -> Dict

Every pair-level difference between N3 and v4 on the declared search domains, classified.
`report_to_user` is true when a pending class or an unclassified difference occurs.
"""
function known_difference_report(domains=(:four_unit_exhaustive, :six_unit_sequence); seed=20260910)
    classes = known_differences()
    status = Dict(c["id"] => c["status"] for c in classes)
    blocks = Dict{String,Any}[]
    for domain in domains
        counts = Dict{String,Int}()
        examples = Dict{String,Vector{Int}}()
        v4_pairs = 0; n3_pairs = 0; circuits = 0
        for_each_search_circuit(domain, nothing, seed) do c, id
            circuits += 1
            m = measure_circuit(c; all_interventions=false)
            loss(u) = m.losses[1 << (findfirst(==(u), c.units) - 1)]
            mine = Set(Set(p) for p in check_dc2(m.model).mutual_pairs)
            truth = Set(Set(p) for p in pair_organization(c).pairs)
            v4_pairs += length(truth); n3_pairs += length(mine)
            for (kind, diff) in (("pair_missed_by_N3", setdiff(truth, mine)), ("pair_extra_in_N3", setdiff(mine, truth)))
                for p in diff
                    k = classify_difference(kind, sort!(collect(p)), c.motors, loss, classes)
                    counts[k] = get(counts, k, 0) + 1
                    length(get!(examples, k, Int[])) < 5 && push!(examples[k], id)
                end
            end
        end
        known = sum((v for (k, v) in counts if get(status, k, "") == "accepted"); init=0)
        push!(blocks, Dict{String,Any}("domain" => String(domain), "circuits" => circuits,
            "v4_pairs" => v4_pairs, "n3_pairs" => n3_pairs, "difference_counts" => counts,
            "examples" => examples, "accepted_difference_count" => known,
            "accepted_share_of_differences" => isempty(counts) ? 0.0 : known / sum(values(counts)),
            # Falsification metric (DC2-HUNIT-N3 §6 decision 7): how much of the truth the accepted
            # differences cover. Reported every time; no threshold, the user judges.
            "accepted_share_of_v4_pairs" => v4_pairs == 0 ? 0.0 : known / v4_pairs))
    end
    flagged = sort!(unique([k for b in blocks for k in keys(b["difference_counts"]) if get(status, k, "") != "accepted"]))
    Dict{String,Any}("schema_version" => 1, "ground_truth" => "specs/packets/DC2-GROUND-TRUTH-004.md",
        "known_differences_sha256" => bytes2hex(open(sha256, KNOWN_DIFFERENCES_FIXTURE)),
        "domains" => blocks, "reported_classes" => flagged, "report_to_user" => !isempty(flagged),
        "phenomenal_claim" => "not_certified")
end
