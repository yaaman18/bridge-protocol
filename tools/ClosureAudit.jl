isdefined(@__MODULE__, :ModelAudit) || include("ModelAudit.jl")
isdefined(@__MODULE__, :BackgroundAudit) || include("BackgroundAudit.jl")

module ClosureAudit

import ..ModelAudit
import ..BackgroundAudit
using ERIEC

function check_observed_closure(model)
    ModelAudit._finite_encoding_valid(model) || throw(ArgumentError("invalid finite closure encoding"))
    length(model.C) <= 12 || throw(ArgumentError("closure audit is limited to 12 units"))
    snapshot = deepcopy(model)
    pi = m -> copy(snapshot.pi[m])
    rho = c -> copy(snapshot.rho[c])
    result = ERIEC.nu_phi(pi,rho,snapshot.C)
    result.converged || error("finite relational closure did not converge")
    finite_fixedpoint = ERIEC.check_nu_phi_fixedpoint(pi,rho,result,snapshot.M,snapshot.C)
    postfixed_covered = ERIEC.check_final_coalgebra(pi,rho,result,snapshot.C)
    finite_fixedpoint && postfixed_covered || error("finite greatest fixedpoint checks failed")
    phi_K = Set(ERIEC.Phi(pi,rho,snapshot.kappa))
    self = snapshot.kappa ⊆ phi_K
    included = snapshot.kappa ⊆ result.value
    self && !included && error("postfixed support lies outside the computed greatest fixedpoint")
    (; kappa=copy(snapshot.kappa),nu_phi=copy(result.value),phi_kappa=phi_K,
       hSelf=self,kappa_subset_nu=included,kappa_equals_nu=snapshot.kappa==result.value,
       kappa_outside_nu=setdiff(snapshot.kappa,result.value),nu_outside_kappa=setdiff(result.value,snapshot.kappa),
       iterations=result.iterations,finite_fixedpoint,postfixed_covered,
       checked_carrier_subsets=1 << length(snapshot.C),write_back=false,phenomenal_claim=:not_certified)
end

function _closure_row(name,origin,model)
    result = check_observed_closure(model)
    Dict("name"=>name,"origin"=>origin,"model"=>ModelAudit._model_dict(model),"kappa"=>ModelAudit._audit_names(result.kappa),
        "nu_phi"=>ModelAudit._audit_names(result.nu_phi),"phi_kappa"=>ModelAudit._audit_names(result.phi_kappa),
        "hSelf"=>result.hSelf,"kappa_subset_nu"=>result.kappa_subset_nu,"kappa_equals_nu"=>result.kappa_equals_nu,
        "kappa_outside_nu"=>ModelAudit._audit_names(result.kappa_outside_nu),
        "nu_outside_kappa"=>ModelAudit._audit_names(result.nu_outside_kappa),
        "iterations"=>result.iterations,"greatest_fixedpoint_checked"=>result.finite_fixedpoint,
        "all_postfixed_sets_covered"=>result.postfixed_covered,"checked_carrier_subsets"=>result.checked_carrier_subsets)
end

function _support_expansion_witness()
    old = only(filter(w -> w.name == "without_hAct",BackgroundAudit.adjoint_measured_witnesses())).circuit
    # A distinct initial configuration: the first delay cell is already active.
    # Keep the P3 windows, circuit, roles and thresholds fixed and remeasure everything.
    ModelAudit.AuditCircuit(units=old.units,motors=old.motors,inputs=old.inputs,
        edges=old.edges,thresholds=old.thresholds,
        initial=ntuple(i -> i == 6 ? true : old.initial[i],length(old.units)),
        P=old.P,H=old.H,L=old.L,R=old.R)
end

function closure_audit_report()
    rows = [_closure_row("original_six_unit_witness","measured_P6",ModelAudit.measured_dc_model().model)]
    for witness in BackgroundAudit.adjoint_measured_witnesses()
        measured = ModelAudit.measure_circuit(witness.circuit)
        push!(rows,_closure_row(witness.name,"measured_adjoint_P3",measured.model))
    end
    expansion_circuit = _support_expansion_witness()
    expanded = ModelAudit.measure_circuit(expansion_circuit)
    row = _closure_row("all_dc_with_support_expansion","modified_initial_P3",expanded.model)
    row["circuit"] = ModelAudit.circuit_dict(expansion_circuit)
    row["dc_actual"] = collect(expanded.result.actual)
    row["adjunction_holds"] = BackgroundAudit.check_adjunction_background(expanded.model).holds
    push!(rows,row)
    Dict("schema_version"=>1,"phenomenal_claim"=>"not_certified","execution_certified"=>false,
        "write_back"=>false,"M1_equivalence_claim"=>false,"models"=>rows)
end

end
