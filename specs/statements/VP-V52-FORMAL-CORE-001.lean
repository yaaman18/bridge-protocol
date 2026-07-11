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
#check ERIEC.Gate.na_propagates
#check ERIEC.Gate.gate_na_propagates
#print axioms ERIEC.Gate.na_propagates

#check ERIEC.Gap.second_gc
#check ERIEC.Gap.SingletonImage
#check ERIEC.Gap.sigma_star_eq_induced_iff_singleton
#check ERIEC.Gap.identification_forces_singleton
#check ERIEC.Gap.gapUp_iff_branch
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
#print axioms ERIEC.Decay.psi_isDecay

#check ERIEC.OpenSimC.Hom
#check ERIEC.OpenSimC.Hom.erase
#check ERIEC.OpenSimC.Hom.mapPath_comp
#check ERIEC.OpenSimC.Hom.mapPath_id_comp
#check ERIEC.OpenSimC.Hom.mapPath_comp_id
#check ERIEC.OpenSimC.identityAuditMap
#check ERIEC.OpenSimC.identityAuditMap_noAssumptions
#print axioms ERIEC.OpenSimC.Hom.mapPath_comp

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
#check ERIEC.Centering.dcAt_horizontal_wall_of_any_strength
#print axioms ERIEC.Centering.dcAt_horizontal_wall_of_any_strength

#check ERIEC.Traceability.Stmt
#check ERIEC.Traceability.DocumentAnchored
#check ERIEC.Traceability.vocabularyStatus
#check ERIEC.Traceability.vocabularyStatus_complete
#check ERIEC.Traceability.vocabularyStatus_sound
#check ERIEC.Traceability.vocabularyStatus_cases
#print axioms ERIEC.Traceability.vocabularyStatus_complete

#check ERIEC.RefModelV52.minimalGateAssignment
#check ERIEC.RefModelV52.minimal_gate_phenomenal_na
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
#print axioms ERIEC.RefModelV52.SymmetricDouble.dcAt_zero_center_indistinguishable

end ERIECV52.Statement.VP_V52_FORMAL_CORE_001
