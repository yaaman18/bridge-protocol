import ERIEC

namespace ERIECV52.Statement.VP_V52_FORMAL_CORE_001

#check ERIEC.Gate.Gv
#check ERIEC.Gate.RawEv
#check ERIEC.Gate.GateEv
#check ERIEC.Gate.GateFrame
#check ERIEC.Gate.GateAssignment.gate
#check ERIEC.Gate.raw_pass_sound
#check ERIEC.Gate.raw_fail_sound
#check ERIEC.Gate.gate_pass_sound
#check ERIEC.Gate.gate_fail_sound
#check ERIEC.Gate.raw_ne_na
#check ERIEC.Gate.gate_unique
#check ERIEC.Gate.na_propagates
#check ERIEC.Gate.gate_na_propagates
#print axioms ERIEC.Gate.na_propagates

#check ERIEC.Gap.second_gc
#check ERIEC.Gap.SingletonImage
#check ERIEC.Gap.sigma_star_eq_induced_iff_singleton
#check ERIEC.Gap.degenerate_iff
#check ERIEC.Gap.identification_forces_singleton
#check ERIEC.Gap.identification_forces_degeneracy
#check ERIEC.Gap.gapUp_iff_branch
#check ERIEC.Gap.gapUp_iff
#check ERIEC.Gap.gapDn_iff
#check ERIEC.Gap.gapUp_alpha_two
#check ERIEC.Gap.no_gapUp_under_identification
#check ERIEC.Gap.no_gapDn_under_identification
#check ERIEC.Gap.no_gap_iff_singleton
#check ERIEC.Gap.gap_trichotomy
#print axioms ERIEC.Gap.gapUp_iff_branch

#check ERIEC.Decay.DecayStructure
#check ERIEC.Decay.psi_isDecay
#check ERIEC.Decay.psi2_isDecay
#check ERIEC.Decay.psi_strict_of_not_postfixed
#check ERIEC.Decay.dec_eq_or_strict
#check ERIEC.Decay.abstract_collapse
#check ERIEC.Decay.collapse_of_psi
#print axioms ERIEC.Decay.psi_isDecay

#check ERIEC.OpenSimC.Hom
#check ERIEC.OpenSimC.Hom.erase
#check ERIEC.OpenSimC.Hom.certify
#check ERIEC.OpenSimC.Hom.mapPath_comp
#check ERIEC.OpenSimC.Hom.mapPath_id_comp
#check ERIEC.OpenSimC.Hom.mapPath_comp_id
#check ERIEC.OpenSimC.identityAuditMap
#check ERIEC.OpenSimC.identityAuditMap_noAssumptions
#print axioms ERIEC.OpenSimC.Hom.mapPath_comp

#check ERIEC.Audit.CertifiedSimulation
#check ERIEC.Audit.CertifiedSimulation.mapPath
#check ERIEC.Audit.CertifiedSimulation.mapPath_usesOnly
#print axioms ERIEC.Audit.noTerminalInit_sound

#check ERIEC.KernelOpen.Frame
#check ERIEC.KernelOpen.action_gapUp

#check ERIEC.Centering.InvariantFamily
#check ERIEC.Centering.InvariantFamilyE
#check ERIEC.Centering.InvariantFamilyC
#check ERIEC.Centering.CompatibleIso.toStatF
#check ERIEC.Centering.andFamilyE
#check ERIEC.Centering.iffFamilyC
#check ERIEC.Centering.invariant_fixed
#check ERIEC.Centering.invariantE_fixed
#check ERIEC.Centering.invariantC_fixed
#check ERIEC.Centering.indist_fixed
#check ERIEC.Centering.dcAtFamily
#check ERIEC.Centering.dcAt_horizontal_wall
#check ERIEC.Centering.horizontal_wall
#print axioms ERIEC.Centering.dcAt_horizontal_wall

#check ERIEC.Value.PositiveRelationalValue
#check ERIEC.Value.positiveRelationalValue_invariant
#check ERIEC.Value.positiveValue_inv
#check ERIEC.Value.positiveRelationalValue_iff_hasStructuralWeight
#check ERIEC.Value.positiveRelationalValue_iff_normalized_pos
#print axioms ERIEC.Value.positiveRelationalValue_invariant
#print axioms ERIEC.Value.positiveRelationalValue_iff_normalized_pos

#check ERIEC.Markers.phiMinus
#check ERIEC.Markers.FM1
#check ERIEC.Markers.FM2
#check ERIEC.Markers.staticInH
#check ERIEC.Markers.FM3Frame
#check ERIEC.Markers.FM3Iso
#check ERIEC.Markers.FM3
#check ERIEC.Markers.DynLabInvariantFamily
#check ERIEC.Markers.FM4Frame
#check ERIEC.Markers.FM4Iso
#check ERIEC.Markers.FM4
#check ERIEC.Markers.DynRepInvariantFamily
#check ERIEC.Markers.FullMarkerFrame
#check ERIEC.Markers.FullMarkerIso
#check ERIEC.Markers.FullMarkerCoreIso
#check ERIEC.Markers.FullMarkerCenterSymmetry
#check ERIEC.Markers.FullMarkerFixedCenterSymmetry
#check ERIEC.Markers.ConsciousAt
#check ERIEC.Markers.BlindAt
#check ERIEC.Markers.DynLabRepInvariantFamily
#check ERIEC.Markers.andDynLabRepFamily
#check ERIEC.Markers.orDynLabRepFamily
#check ERIEC.Markers.notDynLabRepFamily
#check ERIEC.Markers.impDynLabRepFamily
#check ERIEC.Markers.iffDynLabRepFamily
#check ERIEC.Markers.trueDynLabRepFamily
#check ERIEC.Markers.falseDynLabRepFamily
#check ERIEC.Markers.phiMinus_bisim
#check ERIEC.Markers.fm1_invariant
#check ERIEC.Markers.fm2_invariant
#check ERIEC.Markers.staticInH_invariant
#check ERIEC.Markers.fm3_invariant
#check ERIEC.Markers.fm4_invariant
#check ERIEC.Markers.consciousAt_invariant
#check ERIEC.Markers.blindAt_invariant
#check ERIEC.Markers.consciousAt_invariant_of_staticInH
#check ERIEC.Markers.blindAt_invariant_of_staticInH
#check ERIEC.Markers.dynLabRep_fixed_of_staticInH
#check ERIEC.Markers.consciousAt_horizontal_wall_of_staticInH
#check ERIEC.Markers.blindAt_horizontal_wall_of_staticInH
#check ERIEC.Markers.fm1_inv
#check ERIEC.Markers.fm2_inv
#check ERIEC.Markers.fm3_inv
#check ERIEC.Markers.fm4_inv
#check ERIEC.Markers.consciousAt_inv
#check ERIEC.Markers.blindAt_inv
#print axioms ERIEC.Markers.fm1_invariant
#print axioms ERIEC.Markers.fm2_invariant
#print axioms ERIEC.Markers.staticInH_invariant
#print axioms ERIEC.Markers.fm3_invariant
#print axioms ERIEC.Markers.fm4_invariant
#print axioms ERIEC.Markers.consciousAt_invariant
#print axioms ERIEC.Markers.blindAt_invariant
#print axioms ERIEC.Markers.consciousAt_invariant_of_staticInH
#print axioms ERIEC.Markers.blindAt_invariant_of_staticInH
#print axioms ERIEC.Markers.dynLabRep_fixed_of_staticInH
#print axioms ERIEC.Markers.consciousAt_horizontal_wall_of_staticInH
#print axioms ERIEC.Markers.blindAt_horizontal_wall_of_staticInH

#check ERIEC.AnalyticFM4.R2
#check ERIEC.AnalyticFM4.coordinateSwap
#check ERIEC.AnalyticFM4.IsUnitary
#check ERIEC.AnalyticFM4.coordinateSwap_unitary
#check ERIEC.AnalyticFM4.coordinateSwap_normSq
#check ERIEC.AnalyticFM4.Frame
#check ERIEC.AnalyticFM4.FM4
#check ERIEC.AnalyticFM4.Iso
#check ERIEC.AnalyticFM4.eigenspace_preserved
#check ERIEC.AnalyticFM4.projection_preserved
#check ERIEC.AnalyticFM4.fm4_invariant
#check ERIEC.AnalyticFM4.HilbertFrame
#check ERIEC.AnalyticFM4.HilbertFM4
#check ERIEC.AnalyticFM4.HilbertIso
#check ERIEC.AnalyticFM4.hilbert_eigenspace_preserved
#check ERIEC.AnalyticFM4.hilbert_projection_preserved
#check ERIEC.AnalyticFM4.hilbert_fm4_invariant
#check ERIEC.AnalyticFM4.ComplexHilbertFrame
#check ERIEC.AnalyticFM4.ComplexHilbertFM4
#check ERIEC.AnalyticFM4.ComplexHilbertIso
#check ERIEC.AnalyticFM4.ComplexHilbertFullMarkerFrame
#check ERIEC.AnalyticFM4.complex_hilbert_eigenspace_preserved
#check ERIEC.AnalyticFM4.complex_hilbert_projection_preserved
#check ERIEC.AnalyticFM4.complex_hilbert_fm4_invariant
#check ERIEC.AnalyticFM4.complex_hilbert_full_marker_fm4_iff
#print axioms ERIEC.AnalyticFM4.coordinateSwap_unitary
#print axioms ERIEC.AnalyticFM4.eigenspace_preserved
#print axioms ERIEC.AnalyticFM4.fm4_invariant
#print axioms ERIEC.AnalyticFM4.hilbert_fm4_invariant
#print axioms ERIEC.AnalyticFM4.complex_hilbert_fm4_invariant
#print axioms ERIEC.AnalyticFM4.complex_hilbert_full_marker_fm4_iff

#check ERIEC.Traceability.Stmt
#check ERIEC.Traceability.DocumentAnchored
#check ERIEC.Traceability.vocabularyStatus
#check ERIEC.Traceability.vocabularyStatus_complete
#check ERIEC.Traceability.vocabularyStatus_sound
#check ERIEC.Traceability.vocabularyStatus_cases
#print axioms ERIEC.Traceability.vocabularyStatus_complete

#check ERIEC.RefModelV52.minimalGateAssignment
#check ERIEC.RefModelV52.minimal_gate_phenomenal_na
#check ERIEC.RefModelV52.recurrentGateAssignment
#check ERIEC.RefModelV52.recurrent_viability_passes
#check ERIEC.RefModelV52.recurrent_phenomenal_bridgeOpen
#check ERIEC.RefModelV52.standardDependency
#check ERIEC.RefModelV52.standardDependency_iff
#check ERIEC.RefModelV52.standardGateAssignment
#check ERIEC.RefModelV52.standard_gate_phenomenal_bridgeOpen
#check ERIEC.RefModelV52.NonDegenerateRecur.IntegratedWitness
#check ERIEC.RefModelV52.NonDegenerateRecur.integratedWitness
#check ERIEC.RefModelV52.NonDegenerateRecur.recurKernelOpen
#check ERIEC.RefModelV52.NonDegenerateRecur.integratedWitness_has_gapUp
#check ERIEC.RefModelV52.NonDegenerateRecur.integratedWitness_has_coupling
#check ERIEC.RefModelV52.NonDegenerateRecur.integratedWitness_has_recur
#check ERIEC.RefModelV52.SymmetricDouble.alpha_sigma_converse
#check ERIEC.RefModelV52.SymmetricDouble.pi_rho_converse
#check ERIEC.RefModelV52.SymmetricDouble.upperRank_full
#check ERIEC.RefModelV52.SymmetricDouble.fm1_false
#check ERIEC.RefModelV52.NonIsomorphicKernels.witness
#check ERIEC.RefModelV52.NonIsomorphicKernels.witness_nonisomorphic
#check ERIEC.RefModelV52.NonDegenerateRecur.witness
#check ERIEC.RefModelV52.NonDegenerateRecur.fullWitness
#check ERIEC.RefModelV52.NonDegenerateRecur.fullWitness_has_recur
#check ERIEC.RefModelV52.NonDegenerateRecur.gapUp_has_two_alpha
#check ERIEC.RefModelV52.SymmetricDouble.fixedCenterSymmetry
#check ERIEC.RefModelV52.SymmetricDouble.horizontalWallWitness
#check ERIEC.RefModelV52.SymmetricDouble.horizontalWallWitness_indistinguishable
#check ERIEC.RefModelV52.SymmetricDouble.dc_at_all
#check ERIEC.RefModelV52.SymmetricDouble.dcAt_zero_center_indistinguishable
#check ERIEC.RefModelV52.SymmetricDouble.positiveValue_false
#check ERIEC.RefModelV52.SymmetricDouble.positiveValue_swapped
#check ERIEC.RefModelV52.SymmetricDouble.positiveValue_true
#check ERIEC.RefModelV52.SymmetricDouble.markerFrame
#check ERIEC.RefModelV52.SymmetricDouble.markerCoreSwap
#check ERIEC.RefModelV52.SymmetricDouble.markerFixedCenterSymmetry
#check ERIEC.RefModelV52.SymmetricDouble.markerConscious_horizontal_wall
#check ERIEC.RefModelV52.SymmetricDouble.markerBlind_horizontal_wall
#check ERIEC.RefModelV52.SymmetricDouble.analyticFrame
#check ERIEC.RefModelV52.SymmetricDouble.analyticSwap
#check ERIEC.RefModelV52.SymmetricDouble.analytic_eigenspace_swapped
#check ERIEC.RefModelV52.SymmetricDouble.analytic_fm4_false
#check ERIEC.RefModelV52.SymmetricDouble.analytic_fm4_swapped
#check ERIEC.RefModelV52.SymmetricDouble.analytic_fm4_true
#check ERIEC.RefModelV52.SymmetricDouble.EuclideanR2
#check ERIEC.RefModelV52.SymmetricDouble.euclideanCoordinateSwapIndices
#check ERIEC.RefModelV52.SymmetricDouble.euclideanCoordinateSwap
#check ERIEC.RefModelV52.SymmetricDouble.euclideanSpectralProjection
#check ERIEC.RefModelV52.SymmetricDouble.euclideanSpectralProjection_eq_id
#check ERIEC.RefModelV52.SymmetricDouble.euclideanAnalyticFrame
#check ERIEC.RefModelV52.SymmetricDouble.euclideanAnalyticSwap
#check ERIEC.RefModelV52.SymmetricDouble.euclidean_hilbert_eigenspace_swapped
#check ERIEC.RefModelV52.SymmetricDouble.euclidean_hilbert_fm4_false
#check ERIEC.RefModelV52.SymmetricDouble.euclidean_hilbert_fm4_swapped
#check ERIEC.RefModelV52.SymmetricDouble.euclidean_hilbert_fm4_true
#check ERIEC.RefModelV52.SymmetricDouble.ComplexEuclideanR2
#check ERIEC.RefModelV52.SymmetricDouble.complexSpectralProjection_eq_id
#check ERIEC.RefModelV52.SymmetricDouble.complexAnalyticFrame
#check ERIEC.RefModelV52.SymmetricDouble.complexAnalyticSwap
#check ERIEC.RefModelV52.SymmetricDouble.complex_hilbert_fm4_swapped
#check ERIEC.RefModelV52.SymmetricDouble.complexMarkerFrame
#check ERIEC.RefModelV52.SymmetricDouble.complexHilbertFullMarker
#check ERIEC.RefModelV52.SymmetricDouble.complexMarkerCoreSwap
#check ERIEC.RefModelV52.SymmetricDouble.complexMarkerFixedCenterSymmetry
#check ERIEC.RefModelV52.SymmetricDouble.complexMarker_fm4_iff
#check ERIEC.RefModelV52.SymmetricDouble.complexMarkerConscious_horizontal_wall
#check ERIEC.RefModelV52.SymmetricDouble.complexMarkerBlind_horizontal_wall
#check ERIEC.RefModelV52.SymmetricDouble.complexMarker_blind_false
#check ERIEC.RefModelV52.SymmetricDouble.complexMarker_not_conscious_false
#check ERIEC.RefModelV52.SymmetricDouble.complexMarker_blind_true
#check ERIEC.RefModelV52.SymmetricDouble.complexMarker_not_conscious_true
#check ERIEC.RefModelV52.SymmetricDouble.SymmetricDoubleCompleteWitness
#check ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleCompleteWitness
#check ERIEC.RefModelV52.SymmetricDouble.markerStep
#check ERIEC.RefModelV52.SymmetricDouble.ThreeStageCollapse
#check ERIEC.RefModelV52.SymmetricDouble.threeStageCollapse
#check ERIEC.RefModelV52.SymmetricDouble.markerStep_zero_one
#check ERIEC.RefModelV52.SymmetricDouble.markerStep_one_two
#check ERIEC.RefModelV52.SymmetricDouble.markerStep_terminal
#check ERIEC.RefModelV52.SymmetricDouble.markerStateEquiv
#check ERIEC.RefModelV52.SymmetricDouble.markerCollapseNext
#check ERIEC.RefModelV52.SymmetricDouble.markerCollapseNext_conjugates
#check ERIEC.RefModelV52.SymmetricDouble.markerCollapseNext_stages
#check ERIEC.RefModelV52.SymmetricDouble.markerInteroception_exchange
#check ERIEC.RefModelV52.SymmetricDouble.markerStep_exchange_iff
#check ERIEC.RefModelV52.SymmetricDouble.collapseFrame
#check ERIEC.RefModelV52.SymmetricDouble.rankedAlpha
#check ERIEC.RefModelV52.SymmetricDouble.rankedSigma
#check ERIEC.RefModelV52.SymmetricDouble.rankedPi
#check ERIEC.RefModelV52.SymmetricDouble.rankedRho
#check ERIEC.RefModelV52.SymmetricDouble.rankedCoreClosure
#check ERIEC.RefModelV52.SymmetricDouble.collapsePhi_eq_rankedCoreClosure
#check ERIEC.RefModelV52.SymmetricDouble.rankedSymmetricDoubleWitness
#check ERIEC.RefModelV52.SymmetricDouble.ranked_top_relations_empty
#check ERIEC.RefModelV52.SymmetricDouble.collapseFrame_zero_data
#check ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame
#check ERIEC.RefModelV52.SymmetricDouble.collapse_update_iterate_swap_commutes
#check ERIEC.RefModelV52.SymmetricDouble.collapse_conf_swap_invariant
#check ERIEC.RefModelV52.SymmetricDouble.collapse_initial_trajectory_swap_invariant
#check ERIEC.RefModelV52.SymmetricDouble.symmetric_double_dynamic_conjugacy
#check ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerFrame
#check ERIEC.RefModelV52.SymmetricDouble.euclideanHilbertFullMarker
#check ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerConscious_horizontal_wall
#check ERIEC.RefModelV52.SymmetricDouble.collapseFrame_fm1_false
#check ERIEC.RefModelV52.SymmetricDouble.collapseFrame_not_fm2_false
#check ERIEC.RefModelV52.SymmetricDouble.euclideanMarker_blind_false
#check ERIEC.RefModelV52.SymmetricDouble.euclideanMarker_not_conscious_false
#check ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleProfiledKernel
#check ERIEC.RefModelV52.SymmetricDouble.SymmetricDoubleMultiplicityWitness
#check ERIEC.RefModelV52.SymmetricDouble.symmetricDouble_realizationMultiplicity_nonisomorphic
#check ERIEC.RefModelV52.SymmetricDouble.SymmetricDoubleCompleteWitness
#check ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleCompleteWitness
#check ERIEC.RefModelV52.SymmetricDouble.symmetric_double_complete
#check ERIEC.RefModelV52.NonIsomorphicKernels.RealizationMultiplicityWitness
#check ERIEC.RefModelV52.NonIsomorphicKernels.realizationMultiplicity_nonisomorphic
#check ERIEC.RefModelV52.NonIsomorphicKernels.realizationMultiplicity_same_profile

/-- Frozen statements for the strengthened §22.5 and §25.6 certificates.
Unlike `#check`, these examples fail if an implementation weakens or changes
the proposition behind a reserved certificate name. -/
example :
    ERIEC.Markers.ConsciousAt
        ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerFrame false 0 ↔
      ERIEC.Markers.ConsciousAt
        ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerFrame true 0 :=
  ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerConscious_horizontal_wall

example :
    ERIEC.Invariance.DynamicIso
        ERIEC.RefModelV52.SymmetricDouble.collapseSwapIso
        ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.stepInt
        ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.stepInt
        ERIEC.RefModelV52.SymmetricDouble.markerInteroception
        ERIEC.RefModelV52.SymmetricDouble.markerInteroception ∧
      (∀ c,
        ERIEC.Invariance.mapConf
            ERIEC.RefModelV52.SymmetricDouble.collapseSwapIso.hC
            ERIEC.RefModelV52.SymmetricDouble.collapseSwapIso.hE
            (ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.update c) =
          ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.update
            (ERIEC.Invariance.mapConf
              ERIEC.RefModelV52.SymmetricDouble.collapseSwapIso.hC
              ERIEC.RefModelV52.SymmetricDouble.collapseSwapIso.hE c)) :=
  ERIEC.RefModelV52.SymmetricDouble.symmetric_double_dynamic_conjugacy

example (n : Nat) :
    ERIEC.Invariance.mapConf
        ERIEC.RefModelV52.SymmetricDouble.swapBool
        ERIEC.RefModelV52.SymmetricDouble.swapBool
        ((ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.update^[n])
          (ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.conf 0)) =
      (ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.update^[n])
        (ERIEC.RefModelV52.SymmetricDouble.collapseDynFrame.conf 0) :=
  ERIEC.RefModelV52.SymmetricDouble.collapse_initial_trajectory_swap_invariant n

example :
    ¬ Nonempty (ERIEC.Invariance.KIso
      ERIEC.RefModelV52.NonIsomorphicKernels.minimalProfiledKernel.static
      ERIEC.RefModelV52.NonIsomorphicKernels.doubleProfiledKernel.static) :=
  ERIEC.RefModelV52.NonIsomorphicKernels.realizationMultiplicity_nonisomorphic

example :
    ERIEC.RefModelV52.NonIsomorphicKernels.minimalProfiledKernel.profile =
      ERIEC.RefModelV52.NonIsomorphicKernels.doubleProfiledKernel.profile :=
  ERIEC.RefModelV52.NonIsomorphicKernels.realizationMultiplicity_same_profile

example (m : Bool) :
    ERIEC.Markers.FM4
        ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerFrame.toFM4 m ↔
      ERIEC.AnalyticFM4.HilbertFM4
        ERIEC.RefModelV52.SymmetricDouble.euclideanAnalyticFrame m :=
  ERIEC.RefModelV52.SymmetricDouble.euclideanMarker_fm4_iff m

example (a e c : Bool) :
    ERIEC.RefModelV52.SymmetricDouble.rankedAlpha true a = ∅ ∧
      ERIEC.RefModelV52.SymmetricDouble.rankedSigma true e = ∅ ∧
      ERIEC.RefModelV52.SymmetricDouble.rankedPi true a = ∅ ∧
      ERIEC.RefModelV52.SymmetricDouble.rankedRho true c = ∅ :=
  ERIEC.RefModelV52.SymmetricDouble.ranked_top_relations_empty a e c

example (w : Bool) (Y : Set Bool) :
    ERIEC.RefModelV52.SymmetricDouble.collapsePhi w Y =
      ERIEC.RefModelV52.SymmetricDouble.rankedCoreClosure.op w Y :=
  ERIEC.RefModelV52.SymmetricDouble.collapsePhi_eq_rankedCoreClosure w Y

example :
    ERIEC.RefModelV52.SymmetricDouble.collapseFrame.kappa 0 = Set.univ ∧
      ERIEC.RefModelV52.SymmetricDouble.collapseFrame.epsilon 0 = Set.univ ∧
      ERIEC.RefModelV52.SymmetricDouble.collapseFrame.boundary = Set.univ ∧
      ERIEC.RefModelV52.SymmetricDouble.collapseFrame.omega 0 = false :=
  ERIEC.RefModelV52.SymmetricDouble.collapseFrame_zero_data

example : Nonempty
    ERIEC.RefModelV52.SymmetricDouble.SymmetricDoubleCompleteWitness :=
  ERIEC.RefModelV52.SymmetricDouble.symmetric_double_complete

example : ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerFrame.stepLabel =
    ERIEC.RefModelV52.SymmetricDouble.markerStep :=
  ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleCompleteWitness.markerLabel_is_three_stage

example :
  ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleCompleteWitness.complexAnalyticMarker =
      ERIEC.RefModelV52.SymmetricDouble.complexHilbertFullMarker :=
  ERIEC.RefModelV52.SymmetricDouble.SymmetricDoubleCompleteWitness.complexAnalyticMarker_is_complex
    ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleCompleteWitness

example :
    ERIEC.Markers.ConsciousAt ERIEC.RefModelV52.SymmetricDouble.complexMarkerFrame false 0 ↔
      ERIEC.Markers.ConsciousAt ERIEC.RefModelV52.SymmetricDouble.complexMarkerFrame true 0 :=
  ERIEC.RefModelV52.SymmetricDouble.SymmetricDoubleCompleteWitness.complex_conscious_horizontal_wall
    ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleCompleteWitness

example : ERIEC.Markers.BlindAt
    ERIEC.RefModelV52.SymmetricDouble.complexMarkerFrame false 0 :=
  ERIEC.RefModelV52.SymmetricDouble.complexMarker_blind_false

example : ERIEC.Markers.BlindAt
    ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerFrame false 0 :=
  ERIEC.RefModelV52.SymmetricDouble.euclideanMarker_blind_false

example : ¬ ERIEC.Markers.ConsciousAt
    ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerFrame false 0 :=
  ERIEC.RefModelV52.SymmetricDouble.euclideanMarker_not_conscious_false

example (m : Bool) :
    ERIEC.Markers.FM4 ERIEC.RefModelV52.SymmetricDouble.complexMarkerFrame.toFM4 m ↔
      ERIEC.AnalyticFM4.ComplexHilbertFM4
        ERIEC.RefModelV52.SymmetricDouble.complexAnalyticFrame m :=
  ERIEC.RefModelV52.SymmetricDouble.complexMarker_fm4_iff m

example : ¬ Nonempty (ERIEC.Invariance.KIso
    ERIEC.RefModelV52.NonIsomorphicKernels.minimalProfiledKernel.static
    ERIEC.RefModelV52.SymmetricDouble.symmetricDoubleProfiledKernel.static) :=
  ERIEC.RefModelV52.SymmetricDouble.symmetricDouble_realizationMultiplicity_nonisomorphic
#print axioms ERIEC.RefModelV52.SymmetricDouble.dcAt_zero_center_indistinguishable
#print axioms ERIEC.RefModelV52.SymmetricDouble.positiveValue_swapped
#print axioms ERIEC.RefModelV52.SymmetricDouble.markerConscious_horizontal_wall
#print axioms ERIEC.RefModelV52.SymmetricDouble.analytic_fm4_swapped
#print axioms ERIEC.RefModelV52.SymmetricDouble.euclidean_hilbert_fm4_swapped
#print axioms ERIEC.RefModelV52.SymmetricDouble.complex_hilbert_fm4_swapped
#print axioms ERIEC.RefModelV52.SymmetricDouble.complexMarker_fm4_iff
#print axioms ERIEC.RefModelV52.SymmetricDouble.complexMarkerConscious_horizontal_wall
#print axioms ERIEC.RefModelV52.SymmetricDouble.complexMarkerBlind_horizontal_wall
#print axioms ERIEC.RefModelV52.SymmetricDouble.complexMarker_blind_false
#print axioms ERIEC.RefModelV52.NonDegenerateRecur.integratedWitness_has_recur
#print axioms ERIEC.RefModelV52.SymmetricDouble.symmetric_double_complete
#print axioms ERIEC.RefModelV52.SymmetricDouble.euclideanSpectralProjection_eq_id
#print axioms ERIEC.RefModelV52.SymmetricDouble.markerStep_terminal
#print axioms ERIEC.RefModelV52.SymmetricDouble.markerCollapseNext_conjugates
#print axioms ERIEC.RefModelV52.SymmetricDouble.markerStep_exchange_iff
#print axioms ERIEC.RefModelV52.SymmetricDouble.symmetric_double_dynamic_conjugacy
#print axioms ERIEC.RefModelV52.SymmetricDouble.collapse_initial_trajectory_swap_invariant
#print axioms ERIEC.RefModelV52.SymmetricDouble.ranked_top_relations_empty
#print axioms ERIEC.RefModelV52.SymmetricDouble.collapsePhi_eq_rankedCoreClosure
#print axioms ERIEC.RefModelV52.SymmetricDouble.collapseFrame_zero_data
#print axioms ERIEC.RefModelV52.SymmetricDouble.collapseFrame_fm1_false
#print axioms ERIEC.RefModelV52.SymmetricDouble.euclideanMarker_blind_false
#print axioms ERIEC.RefModelV52.SymmetricDouble.euclideanMarker_not_conscious_false
#print axioms ERIEC.RefModelV52.SymmetricDouble.symmetricDouble_realizationMultiplicity_nonisomorphic
#print axioms ERIEC.RefModelV52.SymmetricDouble.symmetric_double_complete
#print axioms ERIEC.RefModelV52.SymmetricDouble.euclideanMarkerConscious_horizontal_wall
#print axioms ERIEC.RefModelV52.NonIsomorphicKernels.realizationMultiplicity_nonisomorphic
#print axioms ERIEC.RefModelV52.SymmetricDouble.alpha_sigma_converse
#print axioms ERIEC.RefModelV52.SymmetricDouble.fm1_false

end ERIECV52.Statement.VP_V52_FORMAL_CORE_001
