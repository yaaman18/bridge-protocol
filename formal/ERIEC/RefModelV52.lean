import ERIEC.Centering
import ERIEC.Gap
import ERIEC.Gate
import ERIEC.OpenDynamics
import ERIEC.RefModel.Basic
import ERIEC.RefModel.Stable
import ERIEC.Dynamics
import ERIEC.Grading
import ERIEC.Invariance
import ERIEC.Value
import ERIEC.Markers
import ERIEC.AnalyticFM4
import Mathlib.Analysis.InnerProductSpace.PiL2
import Mathlib.Analysis.InnerProductSpace.Projection.Basic

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

/-- The observable satisfaction profile required by v5.2 §22.5.  The fields
record the four obligations separately, so equality of profiles cannot be
mistaken for an isomorphism of their realizing kernels. -/
structure RealizationProfile where
  hConv : Bool
  sig2 : Bool
  dc : Bool
  fm1 : Bool
deriving DecidableEq

def satisfiedProfile : RealizationProfile :=
  ⟨true, true, true, true⟩

/-- A kernel together with the rank closure and the exact evidence used for
the §22.5 realization profile. -/
structure ProfiledKernel (A E C S W : Type*) [LT W] where
  static : Invariance.StaticFrame A E C S W
  ranked : Grading.RankedClosure W C
  threshold : W
  center : A
  state : S
  hConv : ∀ a e, e ∈ static.alphaRel a ↔ a ∈ static.sigmaRel e
  hConvP : ∀ a c, c ∈ static.piRel a ↔ a ∈ static.rhoRel c
  sig2 : Grading.sig2 ranked threshold
  ranked_supports_state :
    static.kappa state ⊆ ranked.op (static.omega state) (static.kappa state)
  dc : static.DCAt state
  fm1 : Markers.FM1 static center state
  profile : RealizationProfile
  profile_complete : profile = satisfiedProfile

def minimalStaticFrame : Invariance.StaticFrame Unit Unit Unit Unit Bool where
  alphaRel := fun _ => Set.univ
  sigmaRel := fun _ => Set.univ
  piRel := fun _ => Set.univ
  rhoRel := fun _ => Set.univ
  kappa := fun _ => Set.univ
  epsilon := fun _ => Set.univ
  boundary := Set.univ
  omega := fun _ => false

def doubleStaticFrame : Invariance.StaticFrame Bool Unit Unit Unit Bool where
  alphaRel := fun _ => Set.univ
  sigmaRel := fun _ => Set.univ
  piRel
    | false => Set.univ
    | true => ∅
  rhoRel := fun _ => {false}
  kappa := fun _ => Set.univ
  epsilon := fun _ => Set.univ
  boundary := Set.univ
  omega := fun _ => false

/-- Both realizations use the same two-rank closure: the lower rank admits
the point, while the upper rank eliminates every nonempty post-fixed set. -/
def profileRankedClosure : Grading.RankedClosure Bool Unit where
  op := fun w _ => if w then ∅ else Set.univ
  monotone := by
    intro w X Y hXY
    cases w <;> simp

theorem profile_sig2 : Grading.sig2 profileRankedClosure false := by
  intro w hw Y hY hsubset
  cases w
  · simp at hw
  · obtain ⟨c, hc⟩ := hY
    simpa [profileRankedClosure] using hsubset hc

theorem minimalStaticFrame_dc : minimalStaticFrame.DCAt () := by
  constructor
  · intro c _
    simp [Invariance.StaticFrame.DCAt, minimalStaticFrame, Closure.Phi,
      Closure.pi_star, Closure.rho_star]
  constructor
  · intro e _
    simp [Invariance.StaticFrame.DCAt, minimalStaticFrame, Hinge.T_prime,
      Adj.alpha_star, Adj.sigma_star]
  constructor
  · exact ⟨(), by simp [minimalStaticFrame, Hinge.Act, Closure.rho_star,
      Adj.sigma_star]⟩
  · exact ⟨(), by simp [minimalStaticFrame]⟩

theorem minimalStaticFrame_fm1 : Markers.FM1 minimalStaticFrame () () := by
  intro hsubset
  have hpoint : () ∈ minimalStaticFrame.kappa () := by simp [minimalStaticFrame]
  have hphi := hsubset hpoint
  simpa [Markers.phiMinus, minimalStaticFrame, Closure.pi_star,
    Closure.rho_star] using hphi

theorem doubleStaticFrame_dc : doubleStaticFrame.DCAt () := by
  constructor
  · intro c _
    simp [Invariance.StaticFrame.DCAt, doubleStaticFrame, Closure.Phi,
      Closure.pi_star, Closure.rho_star]
  constructor
  · intro e _
    simp [Invariance.StaticFrame.DCAt, doubleStaticFrame, Hinge.T_prime,
      Adj.alpha_star, Adj.sigma_star]
  constructor
  · exact ⟨false, by simp [doubleStaticFrame, Hinge.Act, Closure.rho_star,
      Adj.sigma_star]⟩
  · exact ⟨(), by simp [doubleStaticFrame]⟩

theorem doubleStaticFrame_fm1 : Markers.FM1 doubleStaticFrame false () := by
  intro hsubset
  have hpoint : () ∈ doubleStaticFrame.kappa () := by simp [doubleStaticFrame]
  have hphi := hsubset hpoint
  simpa [Markers.phiMinus, doubleStaticFrame, Closure.pi_star,
    Closure.rho_star] using hphi

def minimalProfiledKernel : ProfiledKernel Unit Unit Unit Unit Bool where
  static := minimalStaticFrame
  ranked := profileRankedClosure
  threshold := false
  center := ()
  state := ()
  hConv := by intro a e; cases a; cases e; simp [minimalStaticFrame]
  hConvP := by intro a c; cases a; cases c; simp [minimalStaticFrame]
  sig2 := profile_sig2
  ranked_supports_state := by
    intro c hc
    simp [minimalStaticFrame, profileRankedClosure]
  dc := minimalStaticFrame_dc
  fm1 := minimalStaticFrame_fm1
  profile := satisfiedProfile
  profile_complete := rfl

def doubleProfiledKernel : ProfiledKernel Bool Unit Unit Unit Bool where
  static := doubleStaticFrame
  ranked := profileRankedClosure
  threshold := false
  center := false
  state := ()
  hConv := by intro a e; cases a <;> cases e <;> simp [doubleStaticFrame]
  hConvP := by intro a c; cases a <;> cases c <;> simp [doubleStaticFrame]
  sig2 := profile_sig2
  ranked_supports_state := by
    intro c hc
    simp [doubleStaticFrame, profileRankedClosure]
  dc := doubleStaticFrame_dc
  fm1 := doubleStaticFrame_fm1
  profile := satisfiedProfile
  profile_complete := rfl

/-- §22.5: two genuinely different kernels satisfy the same hConv, Sig-2,
DC, and FM1 profile. Their action carriers have different cardinalities, so
no `KIso` can exist between the two realizations. -/
structure RealizationMultiplicityWitness where
  minimal : ProfiledKernel Unit Unit Unit Unit Bool
  doubled : ProfiledKernel Bool Unit Unit Unit Bool
  sameProfile : minimal.profile = doubled.profile
  nonisomorphic : ¬ Nonempty (Invariance.KIso minimal.static doubled.static)

def realizationMultiplicityWitness : RealizationMultiplicityWitness where
  minimal := minimalProfiledKernel
  doubled := doubleProfiledKernel
  sameProfile := rfl
  nonisomorphic := by
    rintro ⟨h⟩
    exact not_equiv_unit_bool ⟨h.hA⟩

theorem realizationMultiplicity_nonisomorphic :
    ¬ Nonempty (Invariance.KIso minimalProfiledKernel.static
      doubleProfiledKernel.static) :=
  realizationMultiplicityWitness.nonisomorphic

theorem realizationMultiplicity_same_profile :
    minimalProfiledKernel.profile = doubleProfiledKernel.profile :=
  realizationMultiplicityWitness.sameProfile

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

/-- The `α` and `σ` relations of the symmetric double are converses. -/
theorem alpha_sigma_converse (a e : Bool) :
    e ∈ frame.alphaRel a ↔ a ∈ frame.sigmaRel e := by
  simp [frame, eq_comm]

/-- The `π` and `ρ` relations of the symmetric double are converses. -/
theorem pi_rho_converse (a c : Bool) :
    c ∈ frame.piRel a ↔ a ∈ frame.rhoRel c := by
  simp [frame, eq_comm]

/-- The upper rank stores all centers and environments at every state. -/
theorem upperRank_full (s : Fin 3) :
    frame.kappa s = Set.univ ∧ frame.epsilon s = Set.univ :=
  ⟨rfl, rfl⟩

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

/-- The left center satisfies FM1: deleting it from the `ρ` support removes
its own core contribution, so the full core cannot be contained in `Φ⁻`. -/
theorem fm1_false : Markers.FM1 frame false 0 := by
  intro hsubset
  have hfalse : false ∈ frame.kappa 0 := by
    simp [frame]
  have hphi := hsubset hfalse
  simpa [Markers.phiMinus, frame, Closure.pi_star, Closure.rho_star] using hphi

/-- The left environmental coupling contributes to the viable core. -/
theorem positiveValue_false :
    Value.PositiveRelationalValue frame.sigmaRel frame.piRel frame.rhoRel false := by
  refine ⟨false, ?_, ?_⟩
  · have hpost : Set.univ ⊆ Closure.Phi frame.piRel frame.rhoRel Set.univ := by
      intro c _
      cases c <;> simp [frame, Closure.Phi, Closure.pi_star, Closure.rho_star]
    exact Closure.coinduction (Y := Set.univ) hpost (by simp)
  · show false ∈ Closure.pi_star frame.piRel (frame.sigmaRel false)
    simp [frame, Closure.pi_star]

/-- The E-side instance of v5.2 §25.4(7) for the symmetric double. -/
theorem positiveValue_swapped :
    Value.PositiveRelationalValue frame.sigmaRel frame.piRel frame.rhoRel false ↔
      Value.PositiveRelationalValue frame.sigmaRel frame.piRel frame.rhoRel true := by
  change Value.PositiveRelationalValue frame.sigmaRel frame.piRel frame.rhoRel false ↔
    Value.PositiveRelationalValue frame.sigmaRel frame.piRel frame.rhoRel (swapIso.hE false)
  exact Value.positiveRelationalValue_invariant swapIso false

/-- The right coupling is positive because it is the image of the left one
under the explicit exchange symmetry. -/
theorem positiveValue_true :
    Value.PositiveRelationalValue frame.sigmaRel frame.piRel frame.rhoRel true :=
  positiveValue_swapped.mp positiveValue_false

/-- The analytic representation used by the §25.6 reference model.  The two
centers occupy the two coordinate axes of `R²`. -/
def analyticRepresentation : Bool → AnalyticFM4.R2
  | false => (1, 0)
  | true => (0, 1)

/-- The identity operator has all of `R²` as its eigenspace at eigenvalue one;
the identity is therefore its exact spectral projection. -/
def analyticFrame : AnalyticFM4.Frame Bool where
  representation := analyticRepresentation
  operator := (LinearMap.id : Module.End ℝ AnalyticFM4.R2)
  eigenvalue := 1
  spectralProjection := (LinearMap.id : Module.End ℝ AnalyticFM4.R2)
  projection_mem_eigenspace := by
    intro v
    rw [Module.End.mem_eigenspace_iff]
    simp
  projection_fixes_eigenspace := by
    intro v _hv
    rfl

/-- The exchange of the two centers is represented by the coordinate-exchange
unitary.  It commutes with both the loop operator and its spectral projection. -/
def analyticSwap : AnalyticFM4.Iso analyticFrame analyticFrame where
  hA := swapBool
  U := AnalyticFM4.coordinateSwap
  unitary := AnalyticFM4.coordinateSwap_unitary
  representation_preserves := by
    intro a
    cases a <;> rfl
  eigenvalue_preserves := rfl
  operator_commutes := by
    simp [analyticFrame]
  projection_commutes := by
    simp [analyticFrame]

/-- The analytic eigenspace is transported by the explicit coordinate-swap
unitary in the symmetric reference model. -/
theorem analytic_eigenspace_swapped (v : AnalyticFM4.R2) :
    v ∈ analyticFrame.operator.eigenspace analyticFrame.eigenvalue ↔
      analyticSwap.U v ∈ analyticFrame.operator.eigenspace analyticFrame.eigenvalue := by
  simpa using AnalyticFM4.eigenspace_preserved analyticSwap v

/-- The left center has a nonzero component in the exact spectral subspace. -/
theorem analytic_fm4_false : AnalyticFM4.FM4 analyticFrame false := by
  simp [AnalyticFM4.FM4, analyticFrame, analyticRepresentation]

/-- The unitary exchange transports the analytic FM4 witness from left to
right without weakening it to a bare finite equivalence. -/
theorem analytic_fm4_swapped :
    AnalyticFM4.FM4 analyticFrame false ↔ AnalyticFM4.FM4 analyticFrame true := by
  change AnalyticFM4.FM4 analyticFrame false ↔
    AnalyticFM4.FM4 analyticFrame (analyticSwap.hA false)
  exact AnalyticFM4.fm4_invariant analyticSwap false

theorem analytic_fm4_true : AnalyticFM4.FM4 analyticFrame true :=
  analytic_fm4_swapped.mp analytic_fm4_false

/-- The standard Hilbert-space carrier for the §25.6 action representation. -/
abbrev EuclideanR2 := EuclideanSpace ℝ (Fin 2)

/-- The permutation of the two Euclidean coordinate axes. -/
def euclideanCoordinateSwapIndices : Fin 2 ≃ Fin 2 :=
  Equiv.swap 0 1

/-- Mathlib's genuine linear-isometry equivalence induced by the coordinate
permutation. -/
noncomputable def euclideanCoordinateSwap : EuclideanR2 ≃ₗᵢ[ℝ] EuclideanR2 :=
  LinearIsometryEquiv.piLpCongrLeft 2 ℝ ℝ euclideanCoordinateSwapIndices

/-- The two centers as the standard orthonormal basis vectors of `R²`. -/
noncomputable def euclideanAnalyticRepresentation : Bool → EuclideanR2
  | false => EuclideanSpace.single 0 1
  | true => EuclideanSpace.single 1 1

/-- The exact orthogonal spectral projection used by the reference model.
For the identity loop at eigenvalue one, its eigenspace is all of `R²`. -/
noncomputable def euclideanSpectralProjection : Module.End ℝ EuclideanR2 :=
  ((⊤ : Submodule ℝ EuclideanR2).starProjection).toLinearMap

theorem euclideanSpectralProjection_eq_id :
    euclideanSpectralProjection = (LinearMap.id : Module.End ℝ EuclideanR2) := by
  simp [euclideanSpectralProjection, Submodule.starProjection_top]

/-- The identity loop and identity spectral projection on the standard
Euclidean Hilbert space. -/
noncomputable def euclideanAnalyticFrame : AnalyticFM4.HilbertFrame Bool EuclideanR2 where
  representation := euclideanAnalyticRepresentation
  operator := (LinearMap.id : Module.End ℝ EuclideanR2)
  eigenvalue := 1
  spectralProjection := euclideanSpectralProjection
  projection_mem_eigenspace := by
    intro v
    rw [Module.End.mem_eigenspace_iff]
    simp [euclideanSpectralProjection, Submodule.starProjection_top]
  projection_fixes_eigenspace := by
    intro v _hv
    simp [euclideanSpectralProjection, Submodule.starProjection_top]
  projection_residual_orthogonal := by
    intro v z _hz
    simp [euclideanSpectralProjection, Submodule.starProjection_top]

/-- The §25.6 center exchange as a Mathlib `LinearIsometryEquiv`, with the
operator and spectral projection commuting exactly. -/
noncomputable def euclideanAnalyticSwap :
    AnalyticFM4.HilbertIso euclideanAnalyticFrame euclideanAnalyticFrame where
  hA := swapBool
  U := euclideanCoordinateSwap
  representation_preserves := by
    intro a
    cases a
    · change euclideanCoordinateSwap (EuclideanSpace.single 0 1) =
        EuclideanSpace.single 1 1
      simpa [euclideanCoordinateSwap, euclideanCoordinateSwapIndices] using
        (EuclideanSpace.piLpCongrLeft_single euclideanCoordinateSwapIndices 0 (1 : ℝ))
    · change euclideanCoordinateSwap (EuclideanSpace.single 1 1) =
        EuclideanSpace.single 0 1
      simpa [euclideanCoordinateSwap, euclideanCoordinateSwapIndices] using
        (EuclideanSpace.piLpCongrLeft_single euclideanCoordinateSwapIndices 1 (1 : ℝ))
  eigenvalue_preserves := rfl
  operator_commutes := by
    simp [euclideanAnalyticFrame]
  projection_commutes := by
    simp [euclideanAnalyticFrame, euclideanSpectralProjection_eq_id]

/-- The standard Hilbert-space eigenspace is preserved by the actual
coordinate-exchange linear isometry. -/
theorem euclidean_hilbert_eigenspace_swapped (v : EuclideanR2) :
    v ∈ euclideanAnalyticFrame.operator.eigenspace euclideanAnalyticFrame.eigenvalue ↔
      euclideanAnalyticSwap.U v ∈
        euclideanAnalyticFrame.operator.eigenspace euclideanAnalyticFrame.eigenvalue := by
  simpa using AnalyticFM4.hilbert_eigenspace_preserved euclideanAnalyticSwap v

theorem euclidean_hilbert_fm4_false :
    AnalyticFM4.HilbertFM4 euclideanAnalyticFrame false := by
  simp [AnalyticFM4.HilbertFM4, euclideanAnalyticFrame,
    euclideanAnalyticRepresentation, euclideanSpectralProjection_eq_id]

/-- The standard Hilbert-space FM4 witness is preserved under the §25.6
coordinate-exchange unitary. -/
theorem euclidean_hilbert_fm4_swapped :
    AnalyticFM4.HilbertFM4 euclideanAnalyticFrame false ↔
      AnalyticFM4.HilbertFM4 euclideanAnalyticFrame true := by
  change AnalyticFM4.HilbertFM4 euclideanAnalyticFrame false ↔
    AnalyticFM4.HilbertFM4 euclideanAnalyticFrame (euclideanAnalyticSwap.hA false)
  exact AnalyticFM4.hilbert_fm4_invariant euclideanAnalyticSwap false

theorem euclidean_hilbert_fm4_true :
    AnalyticFM4.HilbertFM4 euclideanAnalyticFrame true :=
  euclidean_hilbert_fm4_swapped.mp euclidean_hilbert_fm4_false

/-- The finite labelling data used to realize the dyn+lab fields of §25.6.
It is the required three-state collapse chain `s₀ → s₁ → s₂`. -/
def markerStep (_ : Bool) (s t : Fin 3) : Prop :=
  (s = 0 ∧ t = 1) ∨ (s = 1 ∧ t = 2)

/-- The explicit finite dynamic witness required by §25.6.  The final state
has no outgoing labelled transition. -/
structure ThreeStageCollapse where
  first : ∀ m, markerStep m 0 1
  second : ∀ m, markerStep m 1 2
  terminal : ∀ m t, ¬ markerStep m 2 t

def threeStageCollapse : ThreeStageCollapse where
  first := by
    intro _m
    exact Or.inl ⟨rfl, rfl⟩
  second := by
    intro _m
    exact Or.inr ⟨rfl, rfl⟩
  terminal := by
    intro _m _t h
    simp [markerStep] at h

theorem markerStep_zero_one (m : Bool) : markerStep m 0 1 :=
  threeStageCollapse.first m

theorem markerStep_one_two (m : Bool) : markerStep m 1 2 :=
  threeStageCollapse.second m

theorem markerStep_terminal (m : Bool) (t : Fin 3) : ¬ markerStep m 2 t :=
  threeStageCollapse.terminal m t

/-- The explicit state isomorphism from the marker model's `Fin 3` states to
the pre-existing obligation 13.1a collapse model. -/
def markerStateEquiv : Fin 3 ≃ RefModel.RefState where
  toFun := Fin.cases .s0 (Fin.cases .s1 fun _ => .s2)
  invFun
    | .s0 => 0
    | .s1 => 1
    | .s2 => 2
  left_inv := by
    intro s
    fin_cases s <;> rfl
  right_inv := by
    intro s
    cases s <;> rfl

/-- Deterministic state update for the three-stage collapse, obtained by
conjugating the established obligation 13.1a update. -/
def markerCollapseNext : Fin 3 → Fin 3 :=
  markerStateEquiv.symm ∘ RefModel.next ∘ markerStateEquiv

/-- The marker collapse update is isomorphic to the existing three-state
reference update, including the terminal-state stutter. -/
theorem markerCollapseNext_conjugates (s : Fin 3) :
    markerStateEquiv (markerCollapseNext s) = RefModel.next (markerStateEquiv s) := by
  simp [markerCollapseNext]

theorem markerCollapseNext_stages :
    markerCollapseNext 0 = 1 ∧ markerCollapseNext 1 = 2 ∧ markerCollapseNext 2 = 2 := by
  constructor
  · apply markerStateEquiv.injective
    change markerStateEquiv (markerCollapseNext 0) = markerStateEquiv 1
    rw [markerCollapseNext_conjugates]
    rfl
  constructor
  · apply markerStateEquiv.injective
    change markerStateEquiv (markerCollapseNext 1) = markerStateEquiv 2
    rw [markerCollapseNext_conjugates]
    rfl
  · apply markerStateEquiv.injective
    change markerStateEquiv (markerCollapseNext 2) = markerStateEquiv 2
    rw [markerCollapseNext_conjugates]
    rfl

def markerInteroception (s : Fin 3) : Bool :=
  s == 0

/-- The actual three-stage configuration used by the symmetric double.  In
contrast to the earlier static skeleton, its intrinsic and environmental
components collapse at the terminal state and its rank records the advance
to the upper stage. -/
def collapseKappa : Fin 3 → Set Bool
  | 0 | 1 => Set.univ
  | 2 => ∅

def collapseEpsilon : Fin 3 → Set Bool :=
  collapseKappa

def collapseRank : Fin 3 → Bool
  | 0 => false
  | 1 | 2 => true

def collapsePhi (w : Bool) (_ : Set Bool) : Set Bool :=
  if w then ∅ else Set.univ

def collapseTheta : Bool → Set Bool → Set Bool :=
  collapsePhi

/-- The rank advances to the upper stage and remains there.  The strict
configuration decrease at that stage is carried by `collapsePhi`. -/
def collapseDrift (_ : Bool) (_ : Set Bool) : Bool :=
  true

def collapseNext : Fin 3 → Fin 3
  | 0 => 1
  | 1 => 2
  | 2 => 2

theorem collapseNext_eq_markerCollapseNext : collapseNext = markerCollapseNext := by
  funext s
  fin_cases s
  · exact markerCollapseNext_stages.1
  · exact markerCollapseNext_stages.2.1
  · exact markerCollapseNext_stages.2.2

def markerCollapseStep (_ : Bool) (s t : Fin 3) : Prop :=
  t = collapseNext s

def collapseFrame : Invariance.StaticFrame Bool Bool Bool (Fin 3) Bool where
  alphaRel := fun a => {e | e = a}
  sigmaRel := fun e => {a | a = e}
  piRel := fun a => {c | c = a}
  rhoRel := fun c => {a | a = c}
  kappa := collapseKappa
  epsilon := collapseEpsilon
  boundary := Set.univ
  omega := collapseRank

def collapseSwapIso : Invariance.KIso collapseFrame collapseFrame where
  hA := swapBool
  hE := swapBool
  hC := swapBool
  hS := Equiv.refl (Fin 3)
  alpha_iff := by
    intro a e
    cases a <;> cases e <;> simp [collapseFrame, swapBool]
  sigma_iff := by
    intro e a
    cases e <;> cases a <;> simp [collapseFrame, swapBool]
  pi_iff := by
    intro a c
    cases a <;> cases c <;> simp [collapseFrame, swapBool]
  rho_iff := by
    intro c a
    cases c <;> cases a <;> simp [collapseFrame, swapBool]
  kappa_image := by
    intro s
    fin_cases s <;> ext c <;> cases c <;>
      simp [collapseFrame, collapseKappa, Invariance.image, swapBool]
  epsilon_image := by
    intro s
    fin_cases s <;> ext e <;> cases e <;>
      simp [collapseFrame, collapseEpsilon, collapseKappa, Invariance.image, swapBool]
  boundary_image := by
    ext c
    cases c <;> simp [collapseFrame, Invariance.image, swapBool]
  omega_eq := by
    intro s
    fin_cases s <;> rfl

/-- The dynamic frame whose configurations realize the labelled three-stage
collapse. Its state update is definitionally connected to `markerCollapseNext`. -/
def collapseDynFrame : Dynamics.DynFrame Bool Bool Bool (Fin 3) where
  phi := collapsePhi
  theta := collapseTheta
  drift := collapseDrift
  kappa := collapseKappa
  epsilon := collapseEpsilon
  omega := collapseRank
  stepInt := markerCollapseStep false
  h_int := by
    intro s t h
    subst t
    fin_cases s <;>
      simp [collapseNext, collapsePhi, collapseTheta, collapseDrift,
        collapseKappa, collapseEpsilon, collapseRank, Dynamics.upd]

theorem collapseDynFrame_static_kappa (s : Fin 3) :
    collapseDynFrame.kappa s = collapseFrame.kappa s :=
  rfl

theorem collapseDynFrame_static_epsilon (s : Fin 3) :
    collapseDynFrame.epsilon s = collapseFrame.epsilon s :=
  rfl

theorem collapseDynFrame_static_rank (s : Fin 3) :
    collapseDynFrame.omega s = collapseFrame.omega s :=
  rfl

theorem collapse_update_swap_commutes (c : Dynamics.Conf Bool Bool Bool) :
    Invariance.mapConf swapBool swapBool (collapseDynFrame.update c) =
      collapseDynFrame.update (Invariance.mapConf swapBool swapBool c) := by
  apply Invariance.upd_bisim swapBool swapBool
  · intro w K
    cases w <;> ext b <;> cases b <;>
      simp [collapseDynFrame, collapsePhi, Invariance.image]
  · intro w X
    cases w <;> ext b <;> cases b <;>
      simp [collapseDynFrame, collapseTheta, collapsePhi, Invariance.image]
  · exact { eq := by intro w K; rfl }

def collapseDynamicIso : Invariance.DynamicIso collapseSwapIso
    (markerCollapseStep false) (markerCollapseStep false)
    markerInteroception markerInteroception where
  step_iff := by
    intro s t
    rfl
  observe_eq := by
    intro s
    rfl

/-- The strengthened §25.6 witness packages all dynamic data that the
horizontal-wall result uses: configuration transport, update commutation,
labelled transition preservation, and observation preservation. -/
structure SymmetricDynamicWitness where
  static : Invariance.KIso collapseFrame collapseFrame
  dynamics : Dynamics.DynFrame Bool Bool Bool (Fin 3)
  kappa_agrees : ∀ s, dynamics.kappa s = collapseFrame.kappa s
  epsilon_agrees : ∀ s, dynamics.epsilon s = collapseFrame.epsilon s
  rank_agrees : ∀ s, dynamics.omega s = collapseFrame.omega s
  step_agrees : dynamics.stepInt = markerCollapseStep false
  dynamicIso : Invariance.DynamicIso static dynamics.stepInt dynamics.stepInt
    markerInteroception markerInteroception
  update_commutes : ∀ c,
    Invariance.mapConf static.hC static.hE (dynamics.update c) =
      dynamics.update (Invariance.mapConf static.hC static.hE c)

def symmetricDynamicWitness : SymmetricDynamicWitness where
  static := collapseSwapIso
  dynamics := collapseDynFrame
  kappa_agrees := collapseDynFrame_static_kappa
  epsilon_agrees := collapseDynFrame_static_epsilon
  rank_agrees := collapseDynFrame_static_rank
  step_agrees := rfl
  dynamicIso := collapseDynamicIso
  update_commutes := collapse_update_swap_commutes

/-- This replaces the former successor-only claim: the symmetric double now
has a full dynamic F-isomorphism witness, including κ/ε/ω, transitions,
observations, and the total update. -/
theorem symmetric_double_dynamic_conjugacy :
    Invariance.DynamicIso collapseSwapIso collapseDynFrame.stepInt
      collapseDynFrame.stepInt markerInteroception markerInteroception ∧
      (∀ c, Invariance.mapConf collapseSwapIso.hC collapseSwapIso.hE
        (collapseDynFrame.update c) = collapseDynFrame.update
          (Invariance.mapConf collapseSwapIso.hC collapseSwapIso.hE c)) :=
  ⟨symmetricDynamicWitness.dynamicIso, symmetricDynamicWitness.update_commutes⟩

/-- The two coordinates are exchanged along with the two action centers. -/
def swapVector : (Bool × Bool) ≃ (Bool × Bool) where
  toFun := fun v => (v.2, v.1)
  invFun := fun v => (v.2, v.1)
  left_inv := by intro v; rcases v with ⟨x, y⟩; rfl
  right_inv := by intro v; rcases v with ⟨x, y⟩; rfl

def markerRepresentation : Bool → Bool × Bool
  | false => (true, false)
  | true => (false, true)

/-- A concrete dyn+lab+rep extension of the symmetric static frame. -/
def markerFrame : Markers.FullMarkerFrame Bool Bool Bool (Fin 3) Nat Bool (Bool × Bool) where
  static := frame
  inH := fun m s => Markers.staticInH frame m s
  stepLabel := markerStep
  interoception := markerInteroception
  representation := markerRepresentation
  spectralProjection := id
  zero := (false, false)

def markerUsesStaticInH : markerFrame.UsesStaticInH := fun _ _ => Iff.rfl

/-- All non-hinge fields commute with the swap.  The hinge field is recovered
from `markerUsesStaticInH` and the static hinge invariance theorem. -/
def markerCoreSwap : Markers.FullMarkerCoreIso markerFrame markerFrame where
  static := swapIso
  hI := Equiv.refl Bool
  step_iff := by
    intro m s t
    rfl
  interoception_preserves := by
    intro s
    rfl
  hV := swapVector
  zero_preserves := rfl
  representation_preserves := by
    intro m
    cases m <;> rfl
  projection_preserves := by
    intro v
    rfl

/-- The state observation is fixed by the center exchange. -/
theorem markerInteroception_exchange (s : Fin 3) :
    markerFrame.interoception (markerCoreSwap.static.hS s) =
      markerCoreSwap.hI (markerFrame.interoception s) :=
  markerCoreSwap.interoception_preserves s

/-- Every labelled transition of the three-stage collapse chain is preserved
by the exchange of centers and the fixed state symmetry. -/
theorem markerStep_exchange_iff (m : Bool) (s t : Fin 3) :
    markerFrame.stepLabel m s t ↔
      markerFrame.stepLabel (markerCoreSwap.static.hA m)
        (markerCoreSwap.static.hS s) (markerCoreSwap.static.hS t) :=
  markerCoreSwap.step_iff m s t

def markerFixedCenterSymmetry :
    Markers.FullMarkerFixedCenterSymmetry markerFrame false true 0 where
  iso := markerCoreSwap
  maps_center := rfl
  fixes_state := rfl

/-- §25.6 realizes the full dyn+lab+rep exchange symmetry, not only its
static projection. -/
theorem markerConscious_horizontal_wall :
    Markers.ConsciousAt markerFrame false 0 ↔ Markers.ConsciousAt markerFrame true 0 :=
  Markers.consciousAt_horizontal_wall_of_staticInH markerUsesStaticInH
    markerFixedCenterSymmetry

theorem markerBlind_horizontal_wall :
    Markers.BlindAt markerFrame false 0 ↔ Markers.BlindAt markerFrame true 0 :=
  Markers.blindAt_horizontal_wall_of_staticInH markerUsesStaticInH
    markerFixedCenterSymmetry

/-- The §25.6 full marker uses the same Euclidean Hilbert representation and
orthogonal spectral projection as `euclideanAnalyticFrame`, rather than the
earlier finite `Bool × Bool` skeleton. Its static and dynamic components are
the collapsing frame above. -/
noncomputable def euclideanMarkerFrame :
    Markers.FullMarkerFrame Bool Bool Bool (Fin 3) Bool Bool EuclideanR2 where
  static := collapseFrame
  inH := fun m s => Markers.staticInH collapseFrame m s
  stepLabel := markerCollapseStep
  interoception := markerInteroception
  representation := euclideanAnalyticRepresentation
  spectralProjection := euclideanSpectralProjection
  zero := 0

def euclideanMarkerUsesStaticInH : euclideanMarkerFrame.UsesStaticInH :=
  fun _ _ => Iff.rfl

/-- A formal link prevents the structural `ConsciousAt` predicate from using
a representation, projection, or zero vector different from the analytic
Hilbert witness. -/
noncomputable def euclideanHilbertFullMarker :
    AnalyticFM4.HilbertFullMarkerFrame Bool Bool Bool (Fin 3) Bool Bool EuclideanR2 where
  marker := euclideanMarkerFrame
  analytic := euclideanAnalyticFrame
  representation_eq := rfl
  spectralProjection_eq := rfl
  zero_eq := rfl

noncomputable def euclideanMarkerCoreSwap :
    Markers.FullMarkerCoreIso euclideanMarkerFrame euclideanMarkerFrame where
  static := collapseSwapIso
  hI := Equiv.refl Bool
  step_iff := by
    intro m s t
    rfl
  interoception_preserves := by
    intro s
    rfl
  hV := euclideanAnalyticSwap.U.toLinearEquiv.toEquiv
  zero_preserves := by
    change euclideanAnalyticSwap.U (0 : EuclideanR2) = 0
    exact euclideanAnalyticSwap.U.map_zero
  representation_preserves := by
    intro m
    change euclideanAnalyticSwap.U (euclideanAnalyticRepresentation m) =
      euclideanAnalyticRepresentation (swapBool m)
    simpa [euclideanAnalyticFrame, euclideanAnalyticSwap] using
      euclideanAnalyticSwap.representation_preserves m
  projection_preserves := by
    intro v
    change euclideanAnalyticSwap.U (euclideanSpectralProjection v) =
      euclideanSpectralProjection (euclideanAnalyticSwap.U v)
    simpa [euclideanAnalyticFrame] using
      AnalyticFM4.hilbert_projection_preserved euclideanAnalyticSwap v

noncomputable def euclideanMarkerFixedCenterSymmetry :
    Markers.FullMarkerFixedCenterSymmetry euclideanMarkerFrame false true 0 where
  iso := euclideanMarkerCoreSwap
  maps_center := rfl
  fixes_state := rfl

theorem euclideanMarker_fm4_iff (m : Bool) :
    Markers.FM4 euclideanMarkerFrame.toFM4 m ↔
      AnalyticFM4.HilbertFM4 euclideanAnalyticFrame m :=
  AnalyticFM4.hilbert_full_marker_fm4_iff euclideanHilbertFullMarker m

/-- The horizontal wall is now established for the actual analytic Hilbert
FM4 component and the collapsing dynamic frame used by the model. -/
theorem euclideanMarkerConscious_horizontal_wall :
    Markers.ConsciousAt euclideanMarkerFrame false 0 ↔
      Markers.ConsciousAt euclideanMarkerFrame true 0 :=
  Markers.consciousAt_horizontal_wall_of_staticInH euclideanMarkerUsesStaticInH
    euclideanMarkerFixedCenterSymmetry

theorem euclideanMarkerBlind_horizontal_wall :
    Markers.BlindAt euclideanMarkerFrame false 0 ↔
      Markers.BlindAt euclideanMarkerFrame true 0 :=
  Markers.blindAt_horizontal_wall_of_staticInH euclideanMarkerUsesStaticInH
    euclideanMarkerFixedCenterSymmetry

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
