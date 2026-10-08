# The registered analysis (RSB-ANALYZE-001). It lives in the criterion package, which is bound by its
# tree OID, so the analysis is preregistered together with the criteria. Every rule below is a rule
# of the analysis plan v2 (specs/drafts/reactivation-analysis-plan-v2.toml); none is chosen here.
# No numeric threshold appears (the redundancy threshold X was removed on 2026-10-07).

using TOML

const ANALYSIS_REPORT_SCHEMA = 1

_bit(mask, i) = (mask >> i) & 1 == 1
_mask_of(names) = foldl((m, x) -> m | (1 << parse(Int, String(x)[2:end])), names; init=0)

"""
    v4_pairs(record, outputs, n) -> Set of sorted index pairs

Ground truth v4 (specs/packets/DC2-GROUND-TRUTH-004.md) read from a case record: core units c ≠ d
with d ∈ loss(c) and c ∈ loss(d), whose dependence passes through a motor on one leg. loss(u) is the
record's single-silencing loss (the `pi` field, recorded for every unit).
"""
function v4_pairs(record, outputs::Integer, n::Integer)
    loss(u) = record["pi"][u + 1]
    K = [i for i in 0:(n - 1) if _bit(record["kappa"], i)]
    motors = [i for i in 0:(n - 1) if _bit(outputs, i)]
    on_leg(a, from, to) = (a == from || _bit(loss(from), a)) && (a == to || _bit(loss(a), to))
    pairs = Set{Tuple{Int,Int}}()
    for (k, c) in enumerate(K), d in K[(k + 1):end]
        _bit(loss(c), d) && _bit(loss(d), c) || continue
        any(a -> on_leg(a, c, d) || on_leg(a, d, c), motors) && push!(pairs, (c, d))
    end
    pairs
end

# The rules of tools/model_audit/fixtures/dc2-known-differences.toml, read from a case record.
const _RECORD_RULES = Dict(
    "D_MOTOR_NOT_SELF_LOST" => (p, motors, loss) -> any(a -> a in p && !_bit(loss(a), a), motors),
    "ONE_LEG_ACTION" => (p, motors, loss) -> begin
        x, y = p
        dir(x, y) = any(a -> _bit(loss(y), a) && _bit(loss(a), x), motors)
        dir(x, y) != dir(y, x)
    end,
    "N3_LOSS_COMPOSITION_EXTRA" => (p, motors, loss) -> begin
        x, y = p
        !(_bit(loss(y), x) && _bit(loss(x), y))
    end)

"""Class of one pair-level difference between N3 and v4, or "UNCLASSIFIED"."""
function classify_record_difference(kind, pair, record, outputs, n, classes)
    loss(u) = record["pi"][u + 1]
    motors = [i for i in 0:(n - 1) if _bit(outputs, i)]
    for c in classes
        c["kind"] == kind || continue
        rule = get(_RECORD_RULES, c["id"], nothing)
        rule === nothing && throw(ArgumentError("no record rule for class $(c["id"])"))
        rule(pair, motors, loss) && return c["id"]
    end
    "UNCLASSIFIED"
end

_not_analyzed(base, reasons) = merge(base, Dict{String,Any}("status" => "not_analyzed", "reasons" => reasons))

"""
    analyze_run(run_dir; profile_path, plan_path, known_differences_path) -> Dict

The report of a completed run under the analysis plan v2. `status` is "not_analyzed" (a stop
condition holds), "run_retracted" (a retraction condition on the run holds; no tally is given) or
"analyzed".
"""
function analyze_run(run_dir::AbstractString; profile_path::AbstractString, plan_path::AbstractString,
        known_differences_path::AbstractString)
    profile_bytes = read(profile_path)
    profile = SubstrateRegistry.validate_profile(profile_bytes;
        version=SubstrateRegistry.profile_schema_version_of(profile_bytes))
    sub, _ = RM.substrate_from_profile(profile)
    n, outputs = RM.nunits(sub), RM.roles(sub).outputs
    plan = SubstrateRegistry.validate_analysis_plan(read(plan_path); version="rsb-analysis-schema-v2")
    classes = TOML.parsefile(known_differences_path)["class"]
    status_of = Dict(c["id"] => c["status"] for c in classes)

    start_path, completion_path = joinpath(run_dir, "run-start.toml"), joinpath(run_dir, "completion.toml")
    base = Dict{String,Any}("report_schema_version" => ANALYSIS_REPORT_SCHEMA,
        "phenomenal_claim" => "not_certified",
        "plan_digest" => bytes2hex(SHA.sha256(read(plan_path))),
        "known_differences_sha256" => bytes2hex(SHA.sha256(read(known_differences_path))))
    isfile(start_path) || return _not_analyzed(base, ["run-start record missing"])
    start = TOML.parsefile(start_path)
    base["run_id"] = start["run_id"]
    base["registration_id"] = start["registration_id"]

    # 0. Stop conditions.
    reasons = String[]
    isfile(completion_path) && TOML.parsefile(completion_path)["status"] == "complete" ||
        push!(reasons, "completion manifest status is not complete")
    ids = String.(start["case_ids"])
    files = isdir(joinpath(run_dir, "cases")) ? readdir(joinpath(run_dir, "cases")) : String[]
    sort(replace.(files, r"\.toml\z" => "")) == sort(ids) || push!(reasons, "case files differ from the registered case ids")
    bindings = Dict(b["criterion_id"] => b for b in plan["criterion_binding"])
    for (id, b) in bindings, case in ids
        path = joinpath(run_dir, "criteria", id, case * ".toml")
        if !isfile(path)
            push!(reasons, "criterion $id has no result for $case")
            break
        end
        r = TOML.parsefile(path)
        (sort!(collect(keys(r["values"]))) == sort(b["value_keys"]) &&
         sort!(collect(keys(r["diagnostics"]))) == sort(b["diagnostic_keys"])) ||
            (push!(reasons, "criterion $id result keys differ from the registration at $case"); break)
    end
    isempty(reasons) || return _not_analyzed(base, reasons)

    cases = [TOML.parsefile(joinpath(run_dir, "cases", c * ".toml")) for c in ids]
    res(id, c) = TOML.parsefile(joinpath(run_dir, "criteria", id, c * ".toml"))
    dc = [res("dc", c) for c in ids]
    dc2 = [res("dc2", c) for c in ids]

    # 1. Retraction conditions.
    run_retract = String[]
    dc2_retract = String[]
    for (k, c) in enumerate(ids)
        v, d = dc[k]["values"], dc[k]["diagnostics"]
        (cases[k]["q"] == 0 && v["dc"]) && push!(run_retract, "ALL-OFF passes DC at $c")
        (v["dc"] && isempty(d["boundary"])) && push!(run_retract, "DC passes with an empty boundary at $c (ISOLATED)")
        w = dc2[k]["values"]
        if w["dc2"]
            all(x -> v[x], ("hSelf", "hSMC", "hAct")) ||
                push!(dc2_retract, "DC2 true and one of hSelf, hSMC, hAct false at $c")
            w["beta_nonempty"] || push!(dc2_retract, "DC2 true and beta empty at $c")
        end
    end
    isempty(run_retract) ||
        return merge(base, Dict{String,Any}("status" => "run_retracted", "reasons" => run_retract))

    # 2–4. DC: primary tally, sensitivity reading dc_T, robustness, descriptive counts.
    total = length(ids)
    pass = count(r -> r["values"]["dc"], dc)
    dc_T(r) = r["diagnostics"]["hSelf_T"] && all(x -> r["values"][x], ("hSMC", "hAct", "hBound"))
    pass_T = count(dc_T, dc)
    rejected(p) = p == 0 || p == total
    classify(r) = begin
        v, d = r["values"], r["diagnostics"]
        v["dc"] ? "pass" :
        v["hBound"] && (v["hSelf"] || d["hSelf_T"]) && (v["hSMC"] || !isempty(d["mask_smc"])) &&
            (v["hAct"] || !isempty(d["mask_act"])) ? "fail_redundancy_ambiguous" : "fail"
    end
    classes_of_cases = classify.(dc)
    dc_report = Dict{String,Any}(
        "case_count" => total, "pass_count" => pass,
        "discrimination_rejects_substrate" => rejected(pass),
        "dc_T_pass_count" => pass_T,
        "dc_T_discrimination_rejects_substrate" => rejected(pass_T),
        "robust_to_redundancy_reading" => rejected(pass) == rejected(pass_T),
        "classification_counts" => Dict(x => count(==(x), classes_of_cases)
                                        for x in ("pass", "fail_redundancy_ambiguous", "fail")),
        "dc_false_dc_T_true" => count(r -> !r["values"]["dc"] && dc_T(r), dc),
        "dc_false_with_mask_smc_or_mask_act" => count(r -> !r["values"]["dc"] &&
            (!isempty(r["diagnostics"]["mask_smc"]) || !isempty(r["diagnostics"]["mask_act"])), dc))

    # 5. DC2: recorded for ratification only.
    dc2_true = [k for k in eachindex(ids) if dc2[k]["values"]["dc2"]]
    dc2_report = Dict{String,Any}(
        "records_retracted" => !isempty(dc2_retract), "retraction_reasons" => dc2_retract,
        "pass_count" => length(dc2_true),
        "pass_count_not_sigma_cover" => count(k -> !dc2[k]["diagnostics"]["sigma_cover"], dc2_true),
        "pass_with_graph_hBound_false" => count(k -> !dc[k]["values"]["hBound"], dc2_true))

    # 6. N3 against the v4 truth, classified by the known-difference registry.
    diff_counts = Dict{String,Int}()
    v4_total = 0
    for (k, case) in enumerate(cases)
        truth = v4_pairs(case, outputs, n)
        mine = Set(Tuple(sort([parse(Int, String(x)[2:end]) for x in p])) for p in dc2[k]["diagnostics"]["mutual_pairs"])
        v4_total += length(truth)
        for (kind, diff) in (("pair_missed_by_N3", setdiff(truth, mine)), ("pair_extra_in_N3", setdiff(mine, truth)))
            for p in diff
                cls = classify_record_difference(kind, p, case, outputs, n, classes)
                diff_counts[cls] = get(diff_counts, cls, 0) + 1
            end
        end
    end
    accepted = sum((v for (c, v) in diff_counts if get(status_of, c, "") == "accepted"); init=0)
    reported = sort!([c for c in keys(diff_counts) if get(status_of, c, "") != "accepted"])
    n3_report = Dict{String,Any}("v4_pairs" => v4_total, "difference_counts" => diff_counts,
        "accepted_share_of_v4_pairs" => v4_total == 0 ? 0.0 : accepted / v4_total,
        "reported_classes" => reported, "report_to_user" => !isempty(reported))

    merge(base, Dict{String,Any}("status" => "analyzed", "dc" => dc_report, "dc2" => dc2_report,
        "n3_unit_informativeness" => n3_report))
end
