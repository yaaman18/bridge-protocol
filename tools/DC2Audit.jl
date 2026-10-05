isdefined(@__MODULE__, :ImplicationMatrixAudit) || include("ImplicationMatrixAudit.jl")

# DC2 audit report (finite-model-audit-progress-20260930 §推奨 1–4). DC2 is the unratified
# experiment of formal-experiments/M1Refinement.lean; nothing here certifies it.
module DC2Audit

import ..ModelAudit
import ..CountermodelAudit
import ..ImplicationMatrixAudit

const DC2_CONTEXTS = ("lean_reference_M1R", "abstract_carrier_C3_M2_E1",
    "abstract_carrier_C4_M2_E1", "one_input_two_motors_P6_H6_L4_R4")

"""Agreement of `check_dc2` with every fact Lean proves about M1–M5."""
function lean_agreement()
    rows = Dict{String,Any}[]
    for ref in ModelAudit.lean_reference_m1r()
        d = ModelAudit.check_dc2(ref.model)
        for (key, expected) in ref.facts
            got = key === :unit ? (expected in d.irreducible_units) : getproperty(d, key)
            want = key === :unit ? true : expected
            push!(rows, Dict("model"=>ref.name, "lean"=>ref.lean, "fact"=>String(key),
                "agrees"=>got == want))
        end
    end
    rows
end

"""All-conditions and single-drop witnesses of DC2's own conditions, per context."""
function separation_table(catalog)
    table = Dict{String,Any}[]
    for context in DC2_CONTEXTS
        rows = [r for r in catalog["models"] if r["context"] == context]
        for p in ModelAudit.DC2_PATTERNS
            match(r, nondeg) = begin
                o = r["observations"]
                (o["hSelf2"], o["hSMC"], o["hHingeNeeded"], o["hUnit"]) == p.values &&
                    (!nondeg || get(o, "nondegenerate", false))
            end
            push!(table, Dict("context"=>context, "pattern"=>p.name,
                "witnesses"=>sort!([r["id"] for r in rows if match(r, false)]),
                "nondegenerate_witnesses"=>sort!([r["id"] for r in rows if match(r, true)])))
        end
    end
    table
end

const DC2_IMPLICATIONS = (:hSelf, :hSMC, :hAct, :beta_nonempty, :hBound, :all_dc)

function implication_cells(matrix)
    [ImplicationMatrixAudit.find_implication(matrix, block["context"], :dc2, goal)
     for block in matrix["contexts"] for goal in DC2_IMPLICATIONS]
end

_count_table(d) = Dict(String(k)=>v for (k, v) in d)

function dc2_audit_report(; measured_search::Bool=true)
    catalog = CountermodelAudit.finite_model_catalog()
    matrix = ImplicationMatrixAudit.implication_matrix_report(catalog)
    c3 = ModelAudit.dc2_carrier_enumeration()
    corpus = ModelAudit.dc2_witness_corpus()
    c4 = ModelAudit.dc2_carrier_sample(4, 2, 1; samples=corpus["c4_sample"]["samples"],
        seed=corpus["c4_sample"]["seed"])
    report = Dict{String,Any}(
        "schema_version"=>1,
        "definition"=>"formal-experiments/M1Refinement.lean ERIEC.M1R.DC2 (not ratified)",
        "lean_agreement"=>lean_agreement(),
        "carrier_C3_M2_E1"=>Dict("encodings"=>c3.encodings, "coverage"=>"exhaustive",
            "pattern_counts"=>_count_table(c3.counts), "nondegenerate_counts"=>_count_table(c3.nondeg),
            "dc2_true"=>c3.dc2_true, "dc2_true_with_kappa_all"=>c3.dc2_kappa_all_count),
        "carrier_C4_M2_E1"=>Dict("samples"=>c4.samples, "seed"=>c4.seed, "coverage"=>"seeded_sample",
            "nondegenerate_counts"=>_count_table(c4.nondeg_counts)),
        "separation"=>separation_table(catalog),
        "dc2_implications"=>implication_cells(matrix),
        "implication_proved"=>false, "general_impossibility"=>"not_established",
        "phenomenal_claim"=>"not_certified", "execution_certified"=>false)
    if measured_search
        report["measured_search"] = [begin
            s = ModelAudit.dc2_measured_search(domain)
            Dict("domain"=>String(domain), "circuits"=>s.circuits, "exhaustive"=>s.exhaustive,
                "seed"=>20260910, "pattern_counts"=>_count_table(s.counts),
                "nondegenerate_counts"=>_count_table(s.nondeg), "hUnit_true"=>s.hunit_true,
                "nonempty_core_postfixed2"=>s.core_post,
                "of_which_contain_singleton_postfixed2"=>s.core_post_with_singleton)
        end for domain in (:four_unit_exhaustive, :six_unit_sequence)]
    end
    report
end

end
