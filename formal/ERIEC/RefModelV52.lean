import ERIEC.Centering
import ERIEC.Gap
import ERIEC.Gate
import ERIEC.OpenDynamics

namespace ERIEC

namespace RefModelV52

open Gate

/-- §24.6: the six standard guarantee components. -/
inductive GuaranteeIdx where
  | core
  | audit
  | viability
  | generative
  | translation
  | phenomenal
deriving DecidableEq, Repr

open GuaranteeIdx

def minimalClaim : GuaranteeIdx → Prop
  | .core => True
  | .audit => True
  | .viability => False
  | .generative => False
  | .translation => True
  | .phenomenal => True

/-- §24.6: a profile where failed viability blocks the phenomenal component. -/
def minimalGateFrame : GateFrame GuaranteeIdx where
  Claim := minimalClaim
  dep
    | .viability, .phenomenal => True
    | _, _ => False
  raw
    | .core => RawEv.pass trivial
    | .audit => RawEv.pass trivial
    | .viability => RawEv.fail (by intro h; exact h)
    | .generative => RawEv.fail (by intro h; exact h)
    | .translation => RawEv.unk
    | .phenomenal => RawEv.bridgeOpen ⟨"phenomenal bridge remains open"⟩

def minimalGateAssignment : GateAssignment minimalGateFrame where
  ev
    | .core => GateEv.pass trivial
    | .audit => GateEv.pass trivial
    | .viability => GateEv.fail (by intro h; exact h)
    | .generative => GateEv.fail (by intro h; exact h)
    | .translation => GateEv.unk
    | .phenomenal => GateEv.na
  local_na := by
    intro j i hdep _hblock
    cases j <;> cases i <;> simp [minimalGateFrame, eraseEvidence] at hdep ⊢

theorem minimal_viability_fails :
    eraseEvidence (minimalGateAssignment.ev .viability) = Gv.fail := by
  rfl

theorem minimal_gate_viability_fails :
    minimalGateAssignment.gate .viability = Gv.fail := by
  rfl

theorem minimal_phenomenal_na_by_propagation :
    eraseEvidence (minimalGateAssignment.ev .phenomenal) = Gv.na := by
  exact na_propagates minimalGateAssignment
    (DepPath.single (j := GuaranteeIdx.viability) (i := GuaranteeIdx.phenomenal)
      (by simp [minimalGateFrame]))
    (by simp [Blocks, minimalGateAssignment, eraseEvidence])

theorem minimal_gate_phenomenal_na :
    minimalGateAssignment.gate .phenomenal = Gv.na := by
  exact gate_na_propagates minimalGateAssignment
    (DepPath.single (j := GuaranteeIdx.viability) (i := GuaranteeIdx.phenomenal)
      (by simp [minimalGateFrame]))
    (by simp [minimal_gate_viability_fails, Blocks])

/-- §24.6: the same raw phenomenal evidence remains open when no dependency
from viability to phenomenal is selected. -/
def openPhenomenalGateFrame : GateFrame GuaranteeIdx where
  Claim := minimalClaim
  dep := fun _ _ => False
  raw := minimalGateFrame.raw

def openPhenomenalGateAssignment : GateAssignment openPhenomenalGateFrame where
  ev
    | .core => GateEv.pass trivial
    | .audit => GateEv.pass trivial
    | .viability => GateEv.fail (by intro h; exact h)
    | .generative => GateEv.fail (by intro h; exact h)
    | .translation => GateEv.unk
    | .phenomenal => GateEv.bridgeOpen ⟨"phenomenal bridge remains open"⟩
  local_na := by
    intro j i hdep _hblock
    cases j <;> cases i <;> simp [openPhenomenalGateFrame] at hdep

theorem open_phenomenal_bridgeOpen :
    eraseEvidence (openPhenomenalGateAssignment.ev .phenomenal) = Gv.bridgeOpen := by
  rfl

theorem open_gate_phenomenal_bridgeOpen :
    openPhenomenalGateAssignment.gate .phenomenal = Gv.bridgeOpen := by
  rfl

/-- §22.5 support: the one-point carrier and the two-point carrier cannot be
isomorphic, so they can witness multiplicity of non-isomorphic realizations. -/
theorem not_equiv_unit_bool : ¬ Nonempty (Unit ≃ Bool) := by
  rintro ⟨e⟩
  have hpre : e.symm false = e.symm true := by
    cases e.symm false
    cases e.symm true
    rfl
  have h : false = true := by
    calc
      false = e (e.symm false) := (e.apply_symm_apply false).symm
      _ = e (e.symm true) := by rw [hpre]
      _ = true := e.apply_symm_apply true
  cases h

namespace NonIsomorphicKernels

/-- §22.5: a concrete multiplicity witness. The one-point and two-point
carriers cannot be isomorphic, while the two-point carrier supports the
multivalent branch used by the non-degenerate recurrence witness below. -/
structure Witness where
  noEquiv : ¬ Nonempty (Unit ≃ Bool)
  leftPoint : Unit
  rightFalse : Bool
  rightTrue : Bool
  rightDistinct : rightFalse ≠ rightTrue

def witness : Witness where
  noEquiv := not_equiv_unit_bool
  leftPoint := ()
  rightFalse := false
  rightTrue := true
  rightDistinct := by decide

theorem witness_nonisomorphic : ¬ Nonempty (Unit ≃ Bool) :=
  witness.noEquiv

theorem witness_right_has_two :
    witness.rightFalse ≠ witness.rightTrue :=
  witness.rightDistinct

end NonIsomorphicKernels

namespace NonDegenerateRecur

open OpenDynamics

/-- A minimal multivalent `α` relation used as the non-degenerate kernel in
obligation 23.4. -/
def alphaRel (_ : Unit) : Set Bool :=
  Set.univ

/-- The converse-style environment relation for the multivalent kernel. -/
def sigmaRel (_ : Bool) : Set Unit :=
  Set.univ

theorem gapUp : Gap.GapUp alphaRel sigmaRel () := by
  refine ⟨({true} : Set Bool), ?_, ?_⟩
  · simp [Gap.GapUp, Adj.sigma_star, sigmaRel]
  · simp [Gap.GapUp, Adj.sigma_star_induced, alphaRel]

theorem branch : Richness.Branch alphaRel () := by
  refine ⟨false, true, ?_, ?_, ?_⟩
  · simp [alphaRel]
  · simp [alphaRel]
  · decide

theorem gapUp_iff_branch :
    Gap.GapUp alphaRel sigmaRel () ↔ Richness.Branch alphaRel () := by
  apply Gap.gapUp_iff_branch
  intro a e
  cases a
  cases e <;> simp [alphaRel, sigmaRel]

theorem gapUp_has_two_alpha :
    ∃ e₁ e₂, e₁ ∈ alphaRel () ∧ e₂ ∈ alphaRel () ∧ e₁ ≠ e₂ := by
  exact Gap.gapUp_alpha_two (alphaRel := alphaRel) (sigmaRel := sigmaRel)
    (by
      intro a e
      cases a
      cases e <;> simp [alphaRel, sigmaRel])
    gapUp

structure Witness where
  gapUp : Gap.GapUp alphaRel sigmaRel ()
  finiteInternalHorizon :
    OpenDynamics.ReferenceModels.recurFrame.FiniteInternalHorizon
  possibleLive : OpenDynamics.ReferenceModels.recurFrame.PossibleLive

/-- §23.4: non-degenerate discrete recurrence witness, assembled from the
multivalent kernel and the existing open recurrence model `M_recur`. -/
def witness : Witness where
  gapUp := gapUp
  finiteInternalHorizon := OpenDynamics.ReferenceModels.recur_finiteInternalHorizon
  possibleLive := OpenDynamics.ReferenceModels.recur_possibleLive

theorem witness_has_gapUp : witness.gapUp = gapUp :=
  rfl

theorem witness_has_recur :
    OpenDynamics.ReferenceModels.recurFrame.FiniteInternalHorizon ∧
      OpenDynamics.ReferenceModels.recurFrame.PossibleLive :=
  ⟨witness.finiteInternalHorizon, witness.possibleLive⟩

/-- §23.4: the full packaged discrete recurrence witness. This bundles the
multivalent kernel, the gap/branch equivalence, and the open recurrence
liveness properties without adding any continuous-layer assumptions. -/
structure FullWitness where
  base : Witness
  branch : Richness.Branch alphaRel ()
  gapBranchIff : Gap.GapUp alphaRel sigmaRel () ↔ Richness.Branch alphaRel ()
  alphaHasTwo : ∃ e₁ e₂, e₁ ∈ alphaRel () ∧ e₂ ∈ alphaRel () ∧ e₁ ≠ e₂

def fullWitness : FullWitness where
  base := witness
  branch := branch
  gapBranchIff := gapUp_iff_branch
  alphaHasTwo := gapUp_has_two_alpha

theorem fullWitness_has_gapUp : fullWitness.base.gapUp = gapUp :=
  rfl

theorem fullWitness_has_branch : Richness.Branch alphaRel () :=
  fullWitness.branch

theorem fullWitness_has_recur :
    OpenDynamics.ReferenceModels.recurFrame.FiniteInternalHorizon ∧
      OpenDynamics.ReferenceModels.recurFrame.PossibleLive :=
  ⟨fullWitness.base.finiteInternalHorizon, fullWitness.base.possibleLive⟩

end NonDegenerateRecur

namespace SymmetricDouble

open Invariance

def swapBool : Bool ≃ Bool where
  toFun := not
  invFun := not
  left_inv := by intro b; cases b <;> rfl
  right_inv := by intro b; cases b <;> rfl

def frame : StaticFrame Bool Bool Bool (Fin 3) Nat where
  alphaRel := fun a => {e | e = a}
  sigmaRel := fun e => {a | a = e}
  piRel := fun a => {c | c = a}
  rhoRel := fun c => {a | a = c}
  kappa := fun _ => Set.univ
  epsilon := fun _ => Set.univ
  boundary := Set.univ
  omega := fun _ => 0

def swapIso : KIso frame frame where
  hA := swapBool
  hE := swapBool
  hC := swapBool
  hS := Equiv.refl (Fin 3)
  alpha_iff := by
    intro a e
    cases a <;> cases e <;> simp [frame, swapBool]
  sigma_iff := by
    intro e a
    cases e <;> cases a <;> simp [frame, swapBool]
  pi_iff := by
    intro a c
    cases a <;> cases c <;> simp [frame, swapBool]
  rho_iff := by
    intro c a
    cases c <;> cases a <;> simp [frame, swapBool]
  kappa_image := by
    intro s
    ext c
    simp [frame, image]
  epsilon_image := by
    intro s
    ext e
    simp [frame, image]
  boundary_image := by
    ext c
    simp [frame, image]
  omega_eq := by
    intro s
    rfl

def compatibleSwap : Centering.CompatibleIso Centering.Strength.dynLabRep frame frame where
  static := swapIso

def fixedCenterSymmetry :
    Centering.FixedCenterSymmetry Centering.Strength.dynLabRep frame false true 0 where
  iso := compatibleSwap
  maps_center := rfl
  fixes_state := rfl

theorem swapped_centers_distinct : false ≠ true := by
  decide

theorem center_maps_false_true :
    fixedCenterSymmetry.toCenterSymmetry.iso.static.hA false = true := by
  rfl

theorem center_fixes_state_zero :
    fixedCenterSymmetry.toCenterSymmetry.iso.static.hS 0 = 0 := by
  rfl

theorem dcAt_zero_center_indistinguishable :
    Centering.dcAtFamily.Pred frame false 0 ↔ Centering.dcAtFamily.Pred frame true 0 :=
  Centering.dcAt_horizontal_wall_of_any_strength fixedCenterSymmetry

theorem dc_at_all (s : Fin 3) : frame.DCAt s := by
  constructor
  · intro c _hc
    simp [StaticFrame.DCAt, frame, Closure.Phi, Closure.pi_star, Closure.rho_star]
  constructor
  · intro e _he
    simp [StaticFrame.DCAt, frame, Hinge.T_prime, Adj.alpha_star, Adj.sigma_star]
  constructor
  · exact ⟨false, by simp [Hinge.Act, frame, Closure.rho_star, Adj.sigma_star]⟩
  · exact ⟨false, by simp [frame]⟩

theorem dc_at_zero : frame.DCAt 0 :=
  dc_at_all 0

theorem H0_full : ({m : Bool | m = false ∨ m = true} : Set Bool) = Set.univ := by
  ext m
  cases m <;> simp

/-- §25.6: a packaged horizontal-wall witness for the symmetric double. -/
structure HorizontalWallWitness where
  symmetry :
    Centering.FixedCenterSymmetry Centering.Strength.dynLabRep frame false true 0
  centersDistinct : false ≠ true
  mapsCenter : symmetry.toCenterSymmetry.iso.static.hA false = true
  fixesState : symmetry.toCenterSymmetry.iso.static.hS 0 = 0
  dcAtZero : frame.DCAt 0
  indistinguishable :
    Centering.dcAtFamily.Pred frame false 0 ↔ Centering.dcAtFamily.Pred frame true 0

def horizontalWallWitness : HorizontalWallWitness where
  symmetry := fixedCenterSymmetry
  centersDistinct := swapped_centers_distinct
  mapsCenter := center_maps_false_true
  fixesState := center_fixes_state_zero
  dcAtZero := dc_at_zero
  indistinguishable := dcAt_zero_center_indistinguishable

theorem horizontalWallWitness_distinct :
    horizontalWallWitness.centersDistinct = swapped_centers_distinct :=
  rfl

theorem horizontalWallWitness_indistinguishable :
    Centering.dcAtFamily.Pred frame false 0 ↔ Centering.dcAtFamily.Pred frame true 0 :=
  horizontalWallWitness.indistinguishable

end SymmetricDouble

end RefModelV52

end ERIEC
