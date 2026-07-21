import ERIEC.Adjunction
import ERIEC.InterfaceLinearization
import ERIEC.BridgeFunctor
import ERIEC.StructuralHinge
import ERIEC.ViabilityClosure
import ERIEC.LayerComposition
import ERIEC.Body
import ERIEC.Closure
import ERIEC.Hinge
import ERIEC.Collapse
import ERIEC.Dynamics
import ERIEC.DC
import ERIEC.Sensitivity
import ERIEC.Value
import ERIEC.AnalyticFM4
import ERIEC.World
import ERIEC.WorldDC
import ERIEC.WorldDCRep
import ERIEC.Graded
import ERIEC.OpenDynamics
import ERIEC.Audit
import ERIEC.Lineage
import ERIEC.TheoryTranslation
import ERIEC.Invariance
import ERIEC.RefModel
import ERIEC.Wager
import ERIEC.Gate
import ERIEC.Gap
import ERIEC.Decay
import ERIEC.OpenSimC
import ERIEC.Centering
import ERIEC.Traceability
import ERIEC.RefModelV52
import ERIEC.TemporalDC

namespace ERIEC

open scoped RealInnerProductSpace

/-!
Certified artifact boundary.

This module is intentionally small: it gives the Lean side a compiled artifact
catalog that Julia can read and check. The records are string-level because the
consumer is Julia, while the witness definitions below mention the Lean
declarations directly so missing or renamed declarations break `lake build`.
-/

structure CertifiedContract where
  id : String
  leanModule : String
  leanName : String
  leanKind : String
  juliaSymbol : String
  juliaChecker : String

structure CertifiedArtifact where
  version : Nat
  artifactId : String
  contracts : List CertifiedContract

abbrev WitnessAdjunctionSystem :=
  ERIEC.Adj.ERIESystem

abbrev WitnessDCWorldBridge {M E C S : Type*} {m : Nat}
    (dc : ERIEC.DC M E C S)
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)) :=
  ERIEC.WorldDC.DCWorldBridge dc L

abbrev WitnessPresheafTransitionCoproduct {W : Type} {cat : Graded.ThinCategory W}
    (F G : Graded.Presheaf cat) :=
  Graded.PresheafTransitionCoproduct F G

theorem witness_presheafTransition_naturality {W : Type} {cat : Graded.ThinCategory W}
    {F G : Graded.Presheaf cat}
    (C : Graded.PresheafTransitionCoproduct F G)
    (t : C.Tag)
    {u v : W}
    (huv : cat.leq u v)
    (x : F.Obj v) :
    G.res huv (C.app t v x) = C.app t u (F.res huv x) :=
  Graded.presheafTransition_naturality C t huv x

theorem witness_presheafTransition_outputCopair_unique {W : Type} {cat : Graded.ThinCategory W}
    {F G : Graded.Presheaf cat}
    (C : Graded.PresheafTransitionCoproduct F G)
    (w : W)
    {X : Type}
    (handlers : (t : C.Tag) → G.Obj w → X)
    (f : Graded.PresheafTransitionOutputSum C w → X)
    (h : ∀ (t : C.Tag) (y : G.Obj w),
      f (Graded.presheafTransitionOutputInjection C t w y) = handlers t y) :
    f = Graded.presheafTransitionOutputCopair C w handlers :=
  Graded.presheafTransitionOutputCopair_unique C w handlers f h

theorem witness_noTerminalSetPoint_forbids_terminal {Obj : Type}
    (D : Body.SetPointDiagram Obj)
    (h : Body.NoTerminalSetPoint D) :
    ¬ ∃ t : Obj, ∀ x : Obj, D.reaches x t :=
  Body.noTerminalSetPoint_forbids_terminal D h

def certifiedArtifact : CertifiedArtifact :=
  {
    version := 1
    artifactId := "erie-c-certified-boundary"
    contracts := [
      {
        id := "adjunction.system"
        leanModule := "ERIEC.Adjunction"
        leanName := "ERIESystem"
        leanKind := "structure"
        juliaSymbol := "ERIEStructure"
        juliaChecker := "check_erie_structure"
      },
      {
        id := "adjunction.rigidity"
        leanModule := "ERIEC.Adjunction"
        leanName := "rigidity_of_gc"
        leanKind := "theorem"
        juliaSymbol := "ERIEStructure"
        juliaChecker := "check_relational_rigidity"
      },
      {
        id := "interface.relation_linearization"
        leanModule := "ERIEC.InterfaceLinearization"
        leanName := "convSystem_linearization_eq_adjoint"
        leanKind := "theorem"
        juliaSymbol := "relation_incidence_matrix"
        juliaChecker := "check_converse_adjoint"
      },
      {
        id := "interface.sensitivity_realization"
        leanModule := "ERIEC.InterfaceLinearization"
        leanName := "converse_linearization_eq_sensitivity_adjoint"
        leanKind := "theorem"
        juliaSymbol := "check_relation_sensitivity_bridge"
        juliaChecker := "check_relation_sensitivity_bridge"
      },
      {
        id := "interface.relation_naturality"
        leanModule := "ERIEC.InterfaceLinearization"
        leanName := "relationMatrix_reindex_natural"
        leanKind := "theorem"
        juliaSymbol := "check_relation_linearization_naturality"
        juliaChecker := "check_relation_linearization_naturality"
      },
      {
        id := "interface.relation_lax_naturality"
        leanModule := "ERIEC.InterfaceLinearization"
        leanName := "relationMatrix_lax_natural"
        leanKind := "theorem"
        juliaSymbol := "check_relation_hom_lax_naturality"
        juliaChecker := "check_relation_hom_lax_naturality"
      },
      {
        id := "interface.strict_naturality_counterexample"
        leanModule := "ERIEC.InterfaceLinearization"
        leanName := "strict_naturality_fails_for_relationHom"
        leanKind := "theorem"
        juliaSymbol := "strict_relation_hom_naturality_counterexample"
        juliaChecker := "strict_relation_hom_naturality_counterexample"
      },
      {
        id := "bridge.alpha_only_counterexample"
        leanModule := "ERIEC.BridgeFunctor"
        leanName := "no_alphaOnly_hinge_classifier"
        leanKind := "theorem"
        juliaSymbol := "alpha_only_hinge_counterexample"
        juliaChecker := "alpha_only_hinge_counterexample"
      },
      {
        id := "bridge.raw_gram_counterexample"
        leanModule := "ERIEC.BridgeFunctor"
        leanName := "raw_gram_bridge_counterexample"
        leanKind := "theorem"
        juliaSymbol := "raw_gram_bridge_counterexample"
        juliaChecker := "raw_gram_bridge_counterexample"
      },
      {
        id := "bridge.hinge_object_classifier"
        leanModule := "ERIEC.BridgeFunctor"
        leanName := "hingeClassifyingLoop_nontrivial_iff"
        leanKind := "theorem"
        juliaSymbol := "hinge_classifying_loop"
        juliaChecker := "check_hinge_classifying_loop"
      },
      {
        id := "bridge.hinge_lax_map"
        leanModule := "ERIEC.BridgeFunctor"
        leanName := "hingeClassifyingLoop_lax"
        leanKind := "theorem"
        juliaSymbol := "hinge_classifying_loop"
        juliaChecker := "check_hinge_classifying_loop_lax"
      },
      {
        id := "bridge.hinge_thin_functor"
        leanModule := "ERIEC.BridgeFunctor"
        leanName := "hingeClassifierFunctor_nontrivial_iff"
        leanKind := "theorem"
        juliaSymbol := "check_hinge_classifier_functor_laws"
        juliaChecker := "check_hinge_classifier_functor_laws"
      },
      {
        id := "bridge.hinge_strict_functor"
        leanModule := "ERIEC.BridgeFunctor"
        leanName := "strictHingeClassifier_identity_intertwines"
        leanKind := "theorem"
        juliaSymbol := "check_strict_hinge_classifier_intertwining"
        juliaChecker := "check_strict_hinge_classifier_intertwining"
      },
      {
        id := "bridge.hinge_hilbert_functor"
        leanModule := "ERIEC.BridgeFunctor"
        leanName := "strictHingeHilbertFunctor_nontrivial_iff"
        leanKind := "theorem"
        juliaSymbol := "check_hinge_hilbert_functor"
        juliaChecker := "check_hinge_hilbert_functor"
      },
      {
        id := "bridge.hinge_structural_functor"
        leanModule := "ERIEC.StructuralHinge"
        leanName := "structuralHingeHilbertFunctor_nontrivial_iff"
        leanKind := "theorem"
        juliaSymbol := "structural_hinge_isomorphism_witness"
        juliaChecker := "structural_hinge_isomorphism_witness"
      },
      {
        id := "viability.closure_object"
        leanModule := "ERIEC.ViabilityClosure"
        leanName := "viabilityClosureImage_left_fixed"
        leanKind := "theorem"
        juliaSymbol := "successor_closure"
        juliaChecker := "check_viability_closure"
      },
      {
        id := "viability.closure_functor"
        leanModule := "ERIEC.ViabilityClosure"
        leanName := "viabilityClosureFunctor_left_natural"
        leanKind := "theorem"
        juliaSymbol := "check_viability_closure_naturality"
        juliaChecker := "check_viability_closure_naturality"
      },
      {
        id := "viability.relational_frame"
        leanModule := "ERIEC.ViabilityClosure"
        leanName := "viabilityRelationalFrame_left_fixed"
        leanKind := "theorem"
        juliaSymbol := "check_viability_relational_frame"
        juliaChecker := "check_viability_relational_frame"
      },
      {
        id := "viability.relational_functor"
        leanModule := "ERIEC.ViabilityClosure"
        leanName := "viabilityRelationalFunctor_kappa_natural"
        leanKind := "theorem"
        juliaSymbol := "check_viability_relational_functor"
        juliaChecker := "check_viability_relational_functor"
      },
      {
        id := "layers.viable_to_hilbert"
        leanModule := "ERIEC.LayerComposition"
        leanName := "viableToHilbert_nontrivial_iff"
        leanKind := "theorem"
        juliaSymbol := "check_layer_composition"
        juliaChecker := "check_layer_composition"
      },
      {
        id := "layers.nonfaithful_counterexample"
        leanModule := "ERIEC.LayerComposition"
        leanName := "viableToHilbert_not_faithful"
        leanKind := "theorem"
        juliaSymbol := "layer_composition_nonfaithful_witness"
        juliaChecker := "layer_composition_nonfaithful_witness"
      },
      {
        id := "grading.const_presheaf_antitone"
        leanModule := "ERIEC.Grading"
        leanName := "constPresheaf_iff_antitone"
        leanKind := "theorem"
        juliaSymbol := "check_const_presheaf_antitone"
        juliaChecker := "check_const_presheaf_antitone"
      },
      {
        id := "grading.critical_rank"
        leanModule := "ERIEC.Grading"
        leanName := "nuPhi_empty_above"
        leanKind := "theorem"
        juliaSymbol := "check_sig2_collapse_bound"
        juliaChecker := "check_sig2_collapse_bound"
      },
      {
        id := "closure.nu_phi"
        leanModule := "ERIEC.Closure"
        leanName := "NuPhi"
        leanKind := "structure"
        juliaSymbol := "NuPhiResult"
        juliaChecker := "check_nu_phi_fixedpoint"
      },
      {
        id := "closure.knaster_tarski"
        leanModule := "ERIEC.Closure"
        leanName := "finalCoalgebra"
        leanKind := "theorem"
        juliaSymbol := "NuPhiResult"
        juliaChecker := "check_final_coalgebra"
      },
      {
        id := "hinge.act"
        leanModule := "ERIEC.Hinge"
        leanName := "Act"
        leanKind := "def"
        juliaSymbol := "Act"
        juliaChecker := "check_hinge"
      },
      {
        id := "collapse.critical_slowing"
        leanModule := "ERIEC.Collapse"
        leanName := "hingeCollapse"
        leanKind := "theorem"
        juliaSymbol := "critical_slowing_score"
        juliaChecker := "critical_slowing_score"
      },
      {
        id := "dynamics.finite_collapse"
        leanModule := "ERIEC.Dynamics"
        leanName := "collapse"
        leanKind := "theorem"
        juliaSymbol := "check_finite_collapse"
        juliaChecker := "check_finite_collapse"
      },
      {
        id := "dc.system"
        leanModule := "ERIEC.DC"
        leanName := "DC"
        leanKind := "structure"
        juliaSymbol := "DCResult"
        juliaChecker := "check_DC"
      },
      {
        id := "certification.critical_bound"
        leanModule := "ERIEC.DC"
        leanName := "crit_bound"
        leanKind := "theorem"
        juliaSymbol := "DCResult"
        juliaChecker := "check_critical_bound"
      },
      {
        id := "sensitivity.dual_symmetry"
        leanModule := "ERIEC.Sensitivity"
        leanName := "dualSymmetry"
        leanKind := "theorem"
        juliaSymbol := "sensitivity_tensor"
        juliaChecker := "check_dual_symmetry"
      },
      {
        id := "sensitivity.no_order_unit"
        leanModule := "ERIEC.Sensitivity"
        leanName := "not_id_le_adjoint_comp"
        leanKind := "theorem"
        juliaSymbol := "sensitivity_tensor"
        juliaChecker := "check_adjoint_unit_counterexample"
      },
      {
        id := "world.spectral_band"
        leanModule := "ERIEC.World"
        leanName := "Wld_band"
        leanKind := "def"
        juliaSymbol := "world_band"
        juliaChecker := "world_band"
      },
      {
        id := "value.endogenous"
        leanModule := "ERIEC.Value"
        leanName := "V_endogenous"
        leanKind := "theorem"
        juliaSymbol := "check_value_endogenous"
        juliaChecker := "check_value_endogenous"
      },
      {
        id := "world.actuated"
        leanModule := "ERIEC.World"
        leanName := "WldNontrivial"
        leanKind := "def"
        juliaSymbol := "actuated_world"
        juliaChecker := "world_nontrivial"
      },
      {
        id := "worlddc.bridge"
        leanModule := "ERIEC.WorldDC"
        leanName := "DCWorldBridge"
        leanKind := "structure"
        juliaSymbol := "DCWorldBridge"
        juliaChecker := "check_worlddc_bridge"
      },
      {
        id := "worlddc.no_unconditional_equivalence"
        leanModule := "ERIEC.WorldDC"
        leanName := "no_forward_unconditional"
        leanKind := "theorem"
        juliaSymbol := "check_no_unconditional_worlddc"
        juliaChecker := "check_no_unconditional_worlddc"
      },
      {
        -- formal-only: conditional forward (DC + intertwining representation
        -- ⇒ WldNontrivial). No Julia checker: the Julia layer does not verify
        -- rep/chain/act_fixed, so this is NOT wired into the worlddc.bridge
        -- payload. Lean typecheck is the sole guarantee.
        id := "worlddc.representation.forward"
        leanModule := "ERIEC.WorldDCRep"
        leanName := "wldNontrivial_of_intertwining"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "graded.presheaf_transition_coproduct"
        leanModule := "ERIEC.Graded"
        leanName := "PresheafTransitionCoproduct"
        leanKind := "structure"
        juliaSymbol := "PresheafTransitionCoproduct"
        juliaChecker := "check_presheaf_transition_coproduct"
      },
      {
        id := "decomp.copair_unique"
        leanModule := "ERIEC.Decomp"
        leanName := "copair_unique"
        leanKind := "theorem"
        juliaSymbol := "copair"
        juliaChecker := "check_copair_unique"
      },
      {
        id := "graded.presheaf_transition_naturality"
        leanModule := "ERIEC.Graded"
        leanName := "presheafTransition_naturality"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "check_presheaf_transition_naturality"
      },
      {
        id := "graded.presheaf_transition_output_copair_unique"
        leanModule := "ERIEC.Graded"
        leanName := "presheafTransitionOutputCopair_unique"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "check_presheaf_transition_coproduct"
      },
      {
        id := "body.no_terminal_setpoint"
        leanModule := "ERIEC.Body"
        leanName := "NoTerminalSetPoint"
        leanKind := "def"
        juliaSymbol := "SetPointDiagram"
        juliaChecker := "check_m4_no_terminal_setpoint"
      },
      {
        id := "guard.terminal_iff"
        leanModule := "ERIEC.Guard"
        leanName := "hasTStar_iff_terminal"
        leanKind := "theorem"
        juliaSymbol := "check_terminal_guard"
        juliaChecker := "check_terminal_guard"
      },
      {
        id := "markers.fm_classification"
        leanModule := "ERIEC.Markers"
        leanName := "FMMarkers"
        leanKind := "structure"
        juliaSymbol := "FMMarkers"
        juliaChecker := "classify_action_markers"
      },
      {
        id := "opendynamics.open_graph"
        leanModule := "ERIEC.OpenDynamics"
        leanName := "OpenGraph"
        leanKind := "structure"
        juliaSymbol := "FiniteOpenGraph"
        juliaChecker := "check_open_path"
      },
      {
        id := "audit.simulation"
        leanModule := "ERIEC.Audit"
        leanName := "Simulation"
        leanKind := "structure"
        juliaSymbol := "FiniteSimulation"
        juliaChecker := "check_label_preserving_simulation"
      },
      {
        id := "audit.certified_simulation"
        leanModule := "ERIEC.Audit"
        leanName := "CertifiedSimulation"
        leanKind := "structure"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "lineage.core"
        leanModule := "ERIEC.Lineage"
        leanName := "Lineage"
        leanKind := "structure"
        juliaSymbol := "FiniteLineage"
        juliaChecker := "check_lineage"
      },
      {
        id := "theorytr.phenomenal_guard"
        leanModule := "ERIEC.TheoryTranslation"
        leanName := "phenomenal_notCertified"
        leanKind := "theorem"
        juliaSymbol := "GuaranteeProfile"
        juliaChecker := "GuaranteeProfile"
      },
      {
        id := "invariance.update_bisimulation"
        leanModule := "ERIEC.Invariance"
        leanName := "upd_bisim"
        leanKind := "theorem"
        juliaSymbol := "check_update_bisimulation"
        juliaChecker := "check_update_bisimulation"
      },
      {
        id := "reference_models.v5_1"
        leanModule := "ERIEC.RefModel"
        leanName := "reference_models"
        leanKind := "theorem"
        juliaSymbol := "check_reference_models"
        juliaChecker := "check_reference_models"
      },
      {
        id := "reference_models.stable_v2"
        leanModule := "ERIEC.RefModel"
        leanName := "stable_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_reference_models"
        juliaChecker := "check_reference_models"
      },
      {
        id := "reference_models.dynamic_v2"
        leanModule := "ERIEC.RefModel"
        leanName := "dynamic_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_reference_models"
        juliaChecker := "check_reference_models"
      },
      {
        id := "reference_models.nondegenerate_v2"
        leanModule := "ERIEC.RefModel"
        leanName := "nondegenerate_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_reference_models"
        juliaChecker := "check_reference_models"
      },
      {
        id := "reference_models.arbitrarily_large_dc"
        leanModule := "ERIEC.RefModel"
        leanName := "arbitrarily_large_nondegenerate_dc"
        leanKind := "theorem"
        juliaSymbol := "check_arbitrarily_large_nondegenerate_models"
        juliaChecker := "check_arbitrarily_large_nondegenerate_models"
      },
      {
        id := "reference_models.arbitrarily_large_ax_core_discrete"
        leanModule := "ERIEC.RefModel"
        leanName := "arbitrarily_large_ax_core_discrete_model"
        leanKind := "theorem"
        juliaSymbol := "check_arbitrarily_large_ax_core_discrete_models"
        juliaChecker := "check_arbitrarily_large_ax_core_discrete_models"
      },
      {
        id := "reference_models.arbitrarily_large_three_layer"
        leanModule := "ERIEC.RefModel"
        leanName := "arbitrarily_large_three_layer_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_arbitrarily_large_three_layer_reference_models"
        juliaChecker := "check_arbitrarily_large_three_layer_reference_models"
      },
      {
        id := "wager.frozen_independence"
        leanModule := "ERIEC.Wager"
        leanName := "W6_indep"
        leanKind := "theorem"
        juliaSymbol := "check_wager_independence"
        juliaChecker := "check_wager_independence"
      },
      {
        id := "wager.w5_independence_family"
        leanModule := "ERIEC.Wager"
        leanName := "W5_indep_all"
        leanKind := "theorem"
        juliaSymbol := "check_w5_independence_family"
        juliaChecker := "check_w5_independence_family"
      },
      {
        id := "wager.conservative_extension"
        leanModule := "ERIEC.Wager"
        leanName := "W1_identification_conservative"
        leanKind := "theorem"
        juliaSymbol := "check_wager_conservative_extension"
        juliaChecker := "check_wager_conservative_extension"
      },
      {
        id := "wager.global_protocol_invariant"
        leanModule := "ERIEC.Wager"
        leanName := "global_frozen_protocol_invariant"
        leanKind := "theorem"
        juliaSymbol := "check_frozen_protocol_invariant"
        juliaChecker := "check_frozen_protocol_invariant"
      },
      {
        id := "wager.named_models"
        leanModule := "ERIEC.Wager"
        leanName := "named_frozen_models_boundary"
        leanKind := "theorem"
        juliaSymbol := "check_wager_named_models"
        juliaChecker := "check_wager_named_models"
      },
      {
        id := "wager.w6_cycle_soundness"
        leanModule := "ERIEC.Wager"
        leanName := "W6_of_dc_cycle"
        leanKind := "theorem"
        juliaSymbol := "check_w6_cycle_soundness"
        juliaChecker := "check_w6_cycle_soundness"
      },
      {
        id := "wager.interpretive_model_checker"
        leanModule := "ERIEC.Wager"
        leanName := "frozen_interpretive_checker_soundness"
        leanKind := "theorem"
        juliaSymbol := "check_frozen_wager_interpretive_model"
        juliaChecker := "check_frozen_wager_interpretive_model"
      },
      {
        id := "wager.finite_model_checker"
        leanModule := "ERIEC.Wager"
        leanName := "frozen_model_checker_soundness"
        leanKind := "theorem"
        juliaSymbol := "check_frozen_wager_model"
        juliaChecker := "check_frozen_wager_model"
      },
      {
        id := "wager.full_model_checker"
        leanModule := "ERIEC.Wager"
        leanName := "frozen_full_model_checker_soundness"
        leanKind := "theorem"
        juliaSymbol := "check_frozen_wager_full_model"
        juliaChecker := "check_frozen_wager_full_model"
      },
      {
        id := "richness.branch"
        leanModule := "ERIEC.Richness"
        leanName := "Branch"
        leanKind := "def"
        juliaSymbol := "is_branch_point"
        juliaChecker := "is_branch_point"
      },
      {
        id := "richness.hinge_branch_pump"
        leanModule := "ERIEC.Richness"
        leanName := "hinge_branch_pump"
        leanKind := "theorem"
        juliaSymbol := "check_hinge_branch_pump"
        juliaChecker := "check_hinge_branch_pump"
      },
      {
        id := "generation.dc_viable_translation"
        leanModule := "ERIEC.Generation"
        leanName := "dcViableTranslation"
        leanKind := "def"
        juliaSymbol := "check_dc_viable_translation"
        juliaChecker := "check_dc_viable_translation"
      },
      {
        id := "generation.proliferation_morphism"
        leanModule := "ERIEC.Generation"
        leanName := "ProliferationMorphism"
        leanKind := "structure"
        juliaSymbol := "check_proliferation_morphism"
        juliaChecker := "check_proliferation_morphism"
      },
      {
        id := "generation.lineage_stays_open"
        leanModule := "ERIEC.Generation"
        leanName := "lineage_stays_open"
        leanKind := "theorem"
        juliaSymbol := "check_lineage_stays_open"
        juliaChecker := "check_lineage_stays_open"
      },
      {
        id := "generation.richness_inherits_generational"
        leanModule := "ERIEC.Generation"
        leanName := "richness_inherits_generational"
        leanKind := "theorem"
        juliaSymbol := "check_richness_inherits_generational"
        juliaChecker := "check_richness_inherits_generational"
      },
      {
        id := "generation.rich_lineage_cofinal"
        leanModule := "ERIEC.RefModel.LineageWitness"
        leanName := "rich_lineage_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_rich_lineage_cofinal"
        juliaChecker := "check_rich_lineage_cofinal"
      },
      {
        id := "generation.branched_rich_lineage_cofinal"
        leanModule := "ERIEC.RefModel.LineageWitness"
        leanName := "branched_rich_lineage_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_branched_rich_lineage_cofinal"
        juliaChecker := "check_branched_rich_lineage_cofinal"
      },
      {
        id := "temporaldc.observed_termination"
        leanModule := "ERIEC.TemporalDC"
        leanName := "ObservedTerminationStep"
        leanKind := "def"
        juliaSymbol := "check_observed_termination"
        juliaChecker := "check_observed_termination"
      },
      {
        id := "temporaldc.permanent_termination"
        leanModule := "ERIEC.TemporalDC"
        leanName := "PermanentTerminationStep"
        leanKind := "def"
        juliaSymbol := "check_permanent_termination_prefix"
        juliaChecker := "check_permanent_termination_prefix"
      },
      {
        id := "temporaldc.collapse_trace"
        leanModule := "ERIEC.RefModel.CollapseTrace"
        leanName := "collapse_trace_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_collapse_trace_termination"
        juliaChecker := "check_collapse_trace_termination"
      },
      {
        id := "temporaldc.precarious"
        leanModule := "ERIEC.RefModel.CollapseTrace"
        leanName := "collapse_trace_precarious"
        leanKind := "theorem"
        juliaSymbol := "check_precarious_prefix"
        juliaChecker := "check_precarious_prefix"
      },
      {
        id := "temporaldc.no_escape"
        leanModule := "ERIEC.RefModel.CollapseTrace"
        leanName := "all_mortal_reference_model"
        leanKind := "theorem"
        juliaSymbol := "check_no_escape_prefix"
        juliaChecker := "check_no_escape_prefix"
      },
      {
        id := "meta.sigma_purity"
        leanModule := "ERIEC.MetaSelection"
        leanName := "m4_preserved_of_sigmaPure"
        leanKind := "theorem"
        juliaSymbol := "check_sigma_purity"
        juliaChecker := "check_sigma_purity"
      },
      {
        id := "meta.qd_selection"
        leanModule := "ERIEC.MetaSelection"
        leanName := "SigmaPure"
        leanKind := "def"
        juliaSymbol := "check_selection_nondegenerate"
        juliaChecker := "check_selection_nondegenerate"
      },
      {
        id := "meta.sigma1_experiment"
        leanModule := "ERIEC.MetaSelection"
        leanName := "trace_preserved_of_sigmaPure"
        leanKind := "theorem"
        juliaSymbol := "run_sigma1_experiment"
        juliaChecker := "run_sigma1_experiment"
      },
      {
        id := "meta.individual_adapter"
        leanModule := "ERIEC.MetaSelection"
        leanName := "M4SafeMutation"
        leanKind := "def"
        juliaSymbol := "sigma1_observe_candidate"
        juliaChecker := "sigma1_observe_candidate"
      },
      {
        id := "meta.sigma1_diversity_audit"
        leanModule := "ERIEC.MetaSelection"
        leanName := "DiversityAuditPure"
        leanKind := "def"
        juliaSymbol := "check_sigma1_diversity_resolution"
        juliaChecker := "check_sigma1_diversity_resolution"
      },
      {
        id := "v52.gate.propagation"
        leanModule := "ERIEC.Gate"
        leanName := "gate_na_propagates"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.gate.soundness"
        leanModule := "ERIEC.Gate"
        leanName := "gate_pass_sound"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.gate.unique"
        leanModule := "ERIEC.Gate"
        leanName := "gate_unique"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.gap.branch"
        leanModule := "ERIEC.Gap"
        leanName := "gapUp_iff_branch"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.gap.degeneracy"
        leanModule := "ERIEC.Gap"
        leanName := "identification_forces_degeneracy"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.gap.trichotomy"
        leanModule := "ERIEC.Gap"
        leanName := "gap_trichotomy"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.decay.psi"
        leanModule := "ERIEC.Decay"
        leanName := "psi_strict_of_not_postfixed"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.decay.abstract_collapse"
        leanModule := "ERIEC.Decay"
        leanName := "abstract_collapse"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.decay.collapse_of_psi"
        leanModule := "ERIEC.Decay"
        leanName := "collapse_of_psi"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.decay.psi2"
        leanModule := "ERIEC.Decay"
        leanName := "psi2_isDecay"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.opensimc.identity_audit"
        leanModule := "ERIEC.OpenSimC"
        leanName := "identityAuditMap"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.opensimc.path_units"
        leanModule := "ERIEC.OpenSimC"
        leanName := "mapPath_id_comp"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.opensimc.erase_functor"
        leanModule := "ERIEC.OpenSimC"
        leanName := "eraseFunctor"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.kernelopen.action_gap"
        leanModule := "ERIEC.KernelOpen"
        leanName := "action_gapUp"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.centering.horizontal_wall"
        leanModule := "ERIEC.Centering"
        leanName := "horizontal_wall"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.centering.fixed_specialization"
        leanModule := "ERIEC.Centering"
        leanName := "invariantE_fixed"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.centering.strength_data"
        leanModule := "ERIEC.Centering"
        leanName := "CompatibilityData"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.centering.quantified_closure"
        leanModule := "ERIEC.Centering"
        leanName := "forallActionFamily"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.value.positive_static_invariant"
        leanModule := "ERIEC.Value"
        leanName := "positiveRelationalValue_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.fm1_static_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "fm1_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.fm2_static_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "fm2_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.static_hinge_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "staticInH_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.fm3_dynlab_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "fm3_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.fm4_dynrep_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "fm4_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.conscious_dynlabrep_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "consciousAt_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.blind_dynlabrep_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "blindAt_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.conscious_static_hinge_dynlabrep_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "consciousAt_invariant_of_staticInH"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.blind_static_hinge_dynlabrep_invariant"
        leanModule := "ERIEC.Markers"
        leanName := "blindAt_invariant_of_staticInH"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.dynlabrep_static_hinge_fixed_specialization"
        leanModule := "ERIEC.Markers"
        leanName := "dynLabRep_fixed_of_staticInH"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.conscious_static_hinge_horizontal_wall"
        leanModule := "ERIEC.Markers"
        leanName := "consciousAt_horizontal_wall_of_staticInH"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.blind_static_hinge_horizontal_wall"
        leanModule := "ERIEC.Markers"
        leanName := "blindAt_horizontal_wall_of_staticInH"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.analyticfm4.coordinate_swap_unitary"
        leanModule := "ERIEC.AnalyticFM4"
        leanName := "coordinateSwap_unitary"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.analyticfm4.eigenspace_transport"
        leanModule := "ERIEC.AnalyticFM4"
        leanName := "eigenspace_preserved"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.analyticfm4.hilbert_unitary_invariant"
        leanModule := "ERIEC.AnalyticFM4"
        leanName := "hilbert_fm4_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.analyticfm4.complex_hilbert_unitary_invariant"
        leanModule := "ERIEC.AnalyticFM4"
        leanName := "complex_hilbert_fm4_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.analyticfm4.complex_full_marker_link"
        leanModule := "ERIEC.AnalyticFM4"
        leanName := "complex_hilbert_full_marker_fm4_iff"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.traceability.vocabulary"
        leanModule := "ERIEC.Traceability"
        leanName := "vocabularyStatus_complete"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.traceability.soundness"
        leanModule := "ERIEC.Traceability"
        leanName := "vocabularyStatus_sound"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double"
        leanModule := "ERIEC.RefModelV52"
        leanName := "dcAt_zero_center_indistinguishable"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.recurrent_gate_viability"
        leanModule := "ERIEC.RefModelV52"
        leanName := "recurrent_viability_passes"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.standard_gate_profile"
        leanModule := "ERIEC.RefModelV52"
        leanName := "standard_gate_phenomenal_bridgeOpen"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_positive_value"
        leanModule := "ERIEC.RefModelV52"
        leanName := "positiveValue_swapped"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_full_marker"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclideanMarkerConscious_horizontal_wall"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_analytic_fm4"
        leanModule := "ERIEC.RefModelV52"
        leanName := "analytic_fm4_swapped"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_euclidean_hilbert_fm4"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclidean_hilbert_fm4_swapped"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_complex_hilbert_fm4"
        leanModule := "ERIEC.RefModelV52"
        leanName := "complex_hilbert_fm4_swapped"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_complex_full_marker"
        leanModule := "ERIEC.RefModelV52"
        leanName := "symmetric_double_complete"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_three_stage_dynamics"
        leanModule := "ERIEC.RefModelV52"
        leanName := "markerStep_terminal"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_obs_lab_exchange"
        leanModule := "ERIEC.RefModelV52"
        leanName := "markerStep_exchange_iff"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_converse_relations"
        leanModule := "ERIEC.RefModelV52"
        leanName := "alpha_sigma_converse"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_orthogonal_projection"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclideanSpectralProjection_eq_id"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_dynamic_conjugacy"
        leanModule := "ERIEC.RefModelV52"
        leanName := "symmetric_double_dynamic_conjugacy"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_dynamic_orbit_invariance"
        leanModule := "ERIEC.RefModelV52"
        leanName := "collapse_initial_trajectory_swap_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.markers.analytic_fm4_unitary"
        leanModule := "ERIEC.AnalyticFM4"
        leanName := "hilbert_fm4_invariant"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.analytic_symmetric_double"
        leanModule := "ERIEC.RefModelV52"
        leanName := "analytic_fm4_swapped"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.full_marker_analytic_fm4"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclideanMarker_fm4_iff"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_dynamics"
        leanModule := "ERIEC.RefModelV52"
        leanName := "symmetric_double_dynamic_conjugacy"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_dynamic_iso"
        leanModule := "ERIEC.RefModelV52"
        leanName := "collapseDynamicIso"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_update_bisim"
        leanModule := "ERIEC.RefModelV52"
        leanName := "collapse_update_iterate_swap_commutes"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_full_witness"
        leanModule := "ERIEC.RefModelV52"
        leanName := "symmetricDoubleCompleteWitness"
        leanKind := "def"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.full_marker_conscious_wall"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclideanMarkerConscious_horizontal_wall"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.full_marker_blind_wall"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclideanMarkerBlind_horizontal_wall"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_blind"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclideanMarker_blind_false"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_not_conscious"
        leanModule := "ERIEC.RefModelV52"
        leanName := "euclideanMarker_not_conscious_false"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.symmetric_double_fm1"
        leanModule := "ERIEC.RefModelV52"
        leanName := "fm1_false"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.noniso_multiplicity"
        leanModule := "ERIEC.RefModelV52"
        leanName := "symmetricDouble_realizationMultiplicity_nonisomorphic"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.nondegenerate_recur_full"
        leanModule := "ERIEC.RefModelV52"
        leanName := "fullWitness_has_recur"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.nondegenerate_recur_integrated"
        leanModule := "ERIEC.RefModelV52"
        leanName := "integratedWitness_has_recur"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      },
      {
        id := "v52.refmodel.horizontal_wall_witness"
        leanModule := "ERIEC.RefModelV52"
        leanName := "horizontalWallWitness_indistinguishable"
        leanKind := "theorem"
        juliaSymbol := "-"
        juliaChecker := "-"
      }
    ]
  }

def CertifiedContract.toTsvLine (contract : CertifiedContract) : String :=
  String.intercalate "\t" [
    "contract",
    contract.id,
    contract.leanModule,
    contract.leanName,
    contract.leanKind,
    contract.juliaSymbol,
    contract.juliaChecker
  ]

def CertifiedArtifact.toTsv (artifact : CertifiedArtifact) : String :=
  let header := String.intercalate "\t" [
    "ERIEC_CERTIFIED_ARTIFACT",
    toString artifact.version,
    artifact.artifactId
  ]
  String.intercalate "\n" (header :: artifact.contracts.map CertifiedContract.toTsvLine)

def emitCertifiedArtifact : IO Unit := do
  IO.println certifiedArtifact.toTsv

end ERIEC

def main : IO Unit :=
  ERIEC.emitCertifiedArtifact
