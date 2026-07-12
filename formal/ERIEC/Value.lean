import Mathlib.Data.Finset.Card
import Mathlib.Data.Rat.Cast.Order
import ERIEC.Closure
import ERIEC.DC
import ERIEC.Centering

namespace ERIEC

namespace Value

/-!
Formal guardrail for §4 / §13-5 of
`category/tensor_categorical_v5.md`.

The value tensor side is represented here only as an endogenous structural
quantity: how much an environmental coupling contributes to `nuPhi`.
Phenomenal mattering is a separate predicate. The file proves that structural
weight alone does not entail phenomenal mattering; the entailment requires an
explicit bridge assumption.
-/

variable {E C : Type*} [DecidableEq C]

/-- A finitary proxy for `𝐕_w[e]`: the part of `e`'s contribution that lies in
the self-maintaining core `nuPhi`. This is the structural side only. -/
def viabilityContribution (nuPhi : Finset C) (contribution : E → Finset C)
    (e : E) : Nat :=
  ((contribution e).filter fun c => c ∈ nuPhi).card

/-- §7.1: unnormalized structural value. -/
abbrev raw_V (nuPhi : Finset C) (contribution : E → Finset C)
    (e : E) : Nat :=
  viabilityContribution nuPhi contribution e

/-- Certified cardinality normalization; the nonempty premise is checked by
`V_endogenous` callers before interpreting the quotient as a value weight. -/
def normalized_V (nuPhi : Finset C)
    (contribution : E → Finset C) (e : E) : ℚ :=
  (viabilityContribution nuPhi contribution e : ℚ) / (nuPhi.card : ℚ)

omit [DecidableEq C] in
/-- §7.1: `h₁` makes `kappa` post-fixed, while `h₄` supplies an element of
`kappa`; coinduction therefore makes the greatest fixed core nonempty. -/
theorem V_welldef (piRel : M → Set C) (rhoRel : C → Set M)
    (kappa boundary : Set C)
    (h1 : kappa ⊆ Closure.Phi piRel rhoRel kappa)
    (h4 : (kappa ∩ boundary).Nonempty) :
    (Closure.nu (Closure.Phi piRel rhoRel)).Nonempty := by
  obtain ⟨c, hcKappa, _hcBoundary⟩ := h4
  exact ⟨c, Closure.coinduction h1 hcKappa⟩

/-- §7.2: cardinality normalization lies in the unit interval. -/
theorem V_range (nuPhi : Finset C) (contribution : E → Finset C) (e : E)
    (hNu : nuPhi.Nonempty) :
    0 ≤ normalized_V nuPhi contribution e ∧
      normalized_V nuPhi contribution e ≤ 1 := by
  have hDenPosNat : 0 < nuPhi.card := Finset.card_pos.mpr hNu
  have hDenPosRat : (0 : ℚ) < (nuPhi.card : ℚ) := by
    exact_mod_cast hDenPosNat
  have hCardLe : viabilityContribution nuPhi contribution e ≤ nuPhi.card := by
    apply Finset.card_le_card
    intro c hc
    exact (Finset.mem_filter.mp hc).2
  constructor
  · exact div_nonneg (Nat.cast_nonneg _) hDenPosRat.le
  · apply (div_le_iff₀ hDenPosRat).2
    simpa using (show (viabilityContribution nuPhi contribution e : ℚ) ≤
      (nuPhi.card : ℚ) by exact_mod_cast hCardLe)

/-- Normalized structural value is extensional in already-derived inputs. -/
theorem normalized_V_ext
    {nuPhi₁ nuPhi₂ : Finset C} {contribution₁ contribution₂ : E → Finset C}
    (hNu : nuPhi₁ = nuPhi₂) (hContribution : contribution₁ = contribution₂)
    (e : E) :
    normalized_V nuPhi₁ contribution₁ e = normalized_V nuPhi₂ contribution₂ e := by
  subst nuPhi₂
  subst contribution₂
  rfl

/-- The finite presentation of the greatest self-maintaining core derived
from `piRel` and `rhoRel`. -/
noncomputable def finiteNuPhi [Fintype C]
    (piRel : M → Set C) (rhoRel : C → Set M) : Finset C := by
  classical
  exact Finset.univ.filter fun c => c ∈ Closure.nu (Closure.Phi piRel rhoRel)

/-- The finite contribution of `e`, derived from `sigmaRel` and `piRel`. -/
noncomputable def finiteContribution [Fintype C]
    (sigmaRel : E → Set M) (piRel : M → Set C) (e : E) : Finset C := by
  classical
  exact Finset.univ.filter fun c => c ∈ Closure.pi_star piRel (sigmaRel e)

/-- The normalized value reconstructed solely from the three endogenous
relations named in theorem 7.2. -/
noncomputable def relationalNormalizedV [Fintype C]
    (sigmaRel : E → Set M) (piRel : M → Set C) (rhoRel : C → Set M)
    (e : E) : ℚ :=
  normalized_V (finiteNuPhi piRel rhoRel)
    (finiteContribution sigmaRel piRel) e

/-- The universe-polymorphic positive-value predicate underlying
`0 < relationalNormalizedV`.  It avoids a finiteness assumption by stating
directly that the coupling contribution meets the greatest viable core. -/
def PositiveRelationalValue
    (sigmaRel : E → Set M) (piRel : M → Set C) (rhoRel : C → Set M)
    (e : E) : Prop :=
  (Closure.nu (Closure.Phi piRel rhoRel) ∩
    Closure.pi_star piRel (sigmaRel e)).Nonempty

private theorem positiveRelationalValue_forward
    {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') (e : E)
    (hPos : PositiveRelationalValue F.sigmaRel F.piRel F.rhoRel e) :
    PositiveRelationalValue F'.sigmaRel F'.piRel F'.rhoRel (h.hE e) := by
  rcases hPos with ⟨c, hNu, hContribution⟩
  refine ⟨h.hC c, ?_, ?_⟩
  · have hcImage : h.hC c ∈ Invariance.image h.hC
        (Closure.nu (Closure.Phi F.piRel F.rhoRel)) :=
      ⟨c, hNu, rfl⟩
    rw [(Invariance.static_closure_bisim h).2.1] at hcImage
    exact hcImage
  · rcases (by
      simpa [Closure.pi_star] using hContribution :
        ∃ a, a ∈ F.sigmaRel e ∧ c ∈ F.piRel a) with ⟨a, ha, hc⟩
    simp [Closure.pi_star]
    exact ⟨h.hA a, (h.sigma_iff e a).mp ha, (h.pi_iff a c).mp hc⟩

/-- v5.2 Theorem 25.4(7): positivity of the endogenous value is preserved by
every static frame isomorphism. -/
theorem positiveRelationalValue_invariant
    {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') (e : E) :
    PositiveRelationalValue F.sigmaRel F.piRel F.rhoRel e ↔
      PositiveRelationalValue F'.sigmaRel F'.piRel F'.rhoRel (h.hE e) := by
  constructor
  · exact positiveRelationalValue_forward h e
  · intro hPos
    have hBack := positiveRelationalValue_forward h.symm (h.hE e) hPos
    simpa only [Invariance.KIso.symm, Equiv.symm_apply_apply] using hBack

/-- The `E × S` invariant-family packaging of Theorem 25.4(7).  A
`StaticFrame` represents one rank slice, so the state argument only selects
that slice and does not otherwise enter the predicate. -/
def positiveValue_inv : Centering.InvariantFamilyE Centering.Strength.statF where
  Pred := fun F e _ =>
    PositiveRelationalValue F.sigmaRel F.piRel F.rhoRel e
  invariant := by
    intro A E C S A' E' C' S' W F F' h e _s
    exact positiveRelationalValue_invariant h.static e

/-- §7.2: equal `sigma`, `pi`, and `rho` relations determine equal normalized
value; there is no external target or environmental image argument. -/
theorem V_endogenous [Fintype C]
    {sigma₁ sigma₂ : E → Set M}
    {pi₁ pi₂ : M → Set C} {rho₁ rho₂ : C → Set M}
    (hSigma : sigma₁ = sigma₂) (hPi : pi₁ = pi₂) (hRho : rho₁ = rho₂) :
    relationalNormalizedV sigma₁ pi₁ rho₁ =
      relationalNormalizedV sigma₂ pi₂ rho₂ := by
  subst sigma₂
  subst pi₂
  subst rho₂
  rfl

/-- §7.2: weight each environmental column of a sensitivity tensor by its
normalized structural value. -/
def weighted_O {R : Type*} [Mul R] (tensor : M → E → R) (value : E → R)
    (m : M) (e : E) : R :=
  tensor m e * value e

/-- Weighted sensitivity is extensional in exactly its two inputs. -/
theorem weighted_O_endogenous {R : Type*} [Mul R]
    {tensor₁ tensor₂ : M → E → R} {value₁ value₂ : E → R}
    (hTensor : tensor₁ = tensor₂) (hValue : value₁ = value₂) :
    weighted_O tensor₁ value₁ = weighted_O tensor₂ value₂ := by
  subst tensor₂
  subst value₂
  rfl

/-- Extensionality of the structural value computation: it depends only on
`nuPhi` and the contribution map, not on a phenomenal predicate or set point. -/
theorem viabilityContribution_ext
    {nuPhi₁ nuPhi₂ : Finset C} {contribution₁ contribution₂ : E → Finset C}
    {e : E}
    (hNu : nuPhi₁ = nuPhi₂)
    (hContribution : contribution₁ e = contribution₂ e) :
    viabilityContribution nuPhi₁ contribution₁ e =
      viabilityContribution nuPhi₂ contribution₂ e := by
  simp [viabilityContribution, hNu, hContribution]

/-- Positive structural contribution to `nuPhi`. This is the formal counterpart
of "structural weight" or "viability contribution", not mattering. -/
def HasStructuralWeight (nuPhi : Finset C) (contribution : E → Finset C)
    (e : E) : Prop :=
  0 < viabilityContribution nuPhi contribution e

/-- On finite carriers, `PositiveRelationalValue` is exactly positivity of the
cardinality numerator used by `relationalNormalizedV`. -/
theorem positiveRelationalValue_iff_hasStructuralWeight [Fintype C]
    (sigmaRel : E → Set M) (piRel : M → Set C) (rhoRel : C → Set M)
    (e : E) :
    PositiveRelationalValue sigmaRel piRel rhoRel e ↔
      HasStructuralWeight (finiteNuPhi piRel rhoRel)
        (finiteContribution sigmaRel piRel) e := by
  classical
  rw [HasStructuralWeight, viabilityContribution, Finset.card_pos]
  constructor
  · rintro ⟨c, hcNu, hcContribution⟩
    refine ⟨c, Finset.mem_filter.mpr ⟨?_, ?_⟩⟩
    · simpa [finiteContribution] using hcContribution
    · simpa [finiteNuPhi] using hcNu
  · rintro ⟨c, hc⟩
    rcases Finset.mem_filter.mp hc with ⟨hcContribution, hcNu⟩
    exact ⟨c, by simpa [finiteNuPhi] using hcNu,
      by simpa [finiteContribution] using hcContribution⟩

/-- If the greatest viable core is nonempty, the structural nonempty
intersection is equivalent to strict positivity of the normalized value. -/
theorem positiveRelationalValue_iff_normalized_pos [Fintype C]
    (sigmaRel : E → Set M) (piRel : M → Set C) (rhoRel : C → Set M)
    (e : E) (hNu : (finiteNuPhi piRel rhoRel).Nonempty) :
    PositiveRelationalValue sigmaRel piRel rhoRel e ↔
      0 < relationalNormalizedV sigmaRel piRel rhoRel e := by
  rw [positiveRelationalValue_iff_hasStructuralWeight,
    HasStructuralWeight, relationalNormalizedV, normalized_V]
  have hDenNat : 0 < (finiteNuPhi piRel rhoRel).card := Finset.card_pos.mpr hNu
  have hDenRat : (0 : ℚ) < ((finiteNuPhi piRel rhoRel).card : ℚ) := by
    exact_mod_cast hDenNat
  constructor
  · intro hNumNat
    apply div_pos
    · exact_mod_cast hNumNat
    · exact hDenRat
  · intro hNormalized
    rcases (div_pos_iff.mp hNormalized) with hPositive | hNegative
    · exact_mod_cast hPositive.1
    · exact (False.elim ((not_lt_of_ge hDenRat.le) hNegative.2))

/-- Phenomenal mattering is intentionally a separate predicate. -/
abbrev PhenomenalMattering (E : Type*) := E → Prop

/-- A bridge is the extra §13-5 wager that identifies structural weight with
phenomenal mattering. Without this, the implication is not available. -/
structure MatteringBridge (nuPhi : Finset C) (contribution : E → Finset C)
    (mattering : PhenomenalMattering E) : Prop where
  to_mattering :
    ∀ e, HasStructuralWeight nuPhi contribution e → mattering e

theorem mattering_of_bridge
    {nuPhi : Finset C} {contribution : E → Finset C}
    {mattering : PhenomenalMattering E} {e : E}
    (bridge : MatteringBridge nuPhi contribution mattering)
    (hWeight : HasStructuralWeight nuPhi contribution e) :
    mattering e :=
  bridge.to_mattering e hWeight

/-- A structure-based stable model for theorem 7.3.  It packages the four
ranked relations, their converse laws and antitonicity, Sig-2, one certified
DC state, and the finite presentations of its core and contribution map. -/
structure StableModel (W M E C S : Type*) [Preorder W] [DecidableEq C] where
  alphaRel : W → M → Set E
  sigmaRel : W → E → Set M
  piRel : W → M → Set C
  rhoRel : W → C → Set M
  hConv : ∀ w m e, e ∈ alphaRel w m ↔ m ∈ sigmaRel w e
  hConvP : ∀ w m c, c ∈ piRel w m ↔ m ∈ rhoRel w c
  alphaAntitone : Grading.AntitoneRelation fun w m e => e ∈ alphaRel w m
  sigmaAntitone : Grading.AntitoneRelation fun w e m => m ∈ sigmaRel w e
  piAntitone : Grading.AntitoneRelation fun w m c => c ∈ piRel w m
  rhoAntitone : Grading.AntitoneRelation fun w c m => m ∈ rhoRel w c
  threshold : W
  sig2 : Grading.sig2
    { op := fun w => Closure.Phi (piRel w) (rhoRel w)
      monotone := fun w => Closure.phi_mono (piRel w) (rhoRel w) }
    threshold
  omega : S → W
  kappa : S → Set C
  epsilon : S → Set E
  boundary : Set C
  state : S
  hSelf : kappa state ⊆
    Closure.Phi (piRel (omega state)) (rhoRel (omega state)) (kappa state)
  hSMC : epsilon state ⊆
    Hinge.T_prime (alphaRel (omega state)) (sigmaRel (omega state)) (epsilon state)
  hAct : (Hinge.Act (rhoRel (omega state)) (sigmaRel (omega state))
    kappa epsilon state).Nonempty
  hBound : (kappa state ∩ boundary).Nonempty
  nuPhi : Finset C
  nuPhi_spec : (nuPhi : Set C) =
    Closure.nu (Closure.Phi (piRel (omega state)) (rhoRel (omega state)))
  contribution : E → Finset C
  contribution_spec : ∀ e, (contribution e : Set C) =
    Closure.pi_star (piRel (omega state)) (sigmaRel (omega state) e)
  externalPredicate : E → Prop

/-- The disputed uniform implication from positive structural weight to an
uninterpreted external predicate. -/
def StableTarget {W M E C S : Type*} [Preorder W] [DecidableEq C]
    (model : StableModel W M E C S) : Prop :=
  ∀ e, HasStructuralWeight model.nuPhi model.contribution e →
    model.externalPredicate e

namespace Countermodel

/-- A one-coupling model with a nonzero structural contribution. -/
def nuPhi : Finset Unit := {()}

def contribution (_ : Unit) : Finset Unit := {()}

/-- In the countermodel, phenomenal mattering is absent by stipulation. -/
def mattering : PhenomenalMattering Unit := fun _ => False

theorem has_structural_weight :
    HasStructuralWeight nuPhi contribution () := by
  simp [HasStructuralWeight, viabilityContribution, nuPhi, contribution]

theorem no_phenomenal_mattering :
    ¬ mattering () := by
  intro h
  exact h

/-- Therefore there is no theorem from structural weight alone to phenomenal
mattering. Any such implication would be refuted by this model. -/
theorem no_general_structural_to_mattering :
    ¬ (∀ (nuPhi : Finset Unit) (contribution : Unit → Finset Unit)
        (mattering : PhenomenalMattering Unit),
        HasStructuralWeight nuPhi contribution () → mattering ()) := by
  intro h
  exact no_phenomenal_mattering
    (h nuPhi contribution mattering has_structural_weight)

def gradedRel (w : Bool) (_ : Unit) : Set Unit :=
  if w then ∅ else {()}

theorem gradedRel_antitone :
    Grading.AntitoneRelation fun w m e => e ∈ gradedRel w m := by
  intro low high hle m e he
  cases low <;> cases high
  · simpa [gradedRel] using he
  · simpa [gradedRel] using he
  · exact ((by decide : ¬ true ≤ false) hle).elim
  · simpa [gradedRel] using he

theorem false_phi_identity (Y : Set Unit) :
    Closure.Phi (gradedRel false) (gradedRel false) Y = Y := by
  ext c
  simp [Closure.Phi, Closure.pi_star, Closure.rho_star, gradedRel]

theorem false_nu :
    Closure.nu (Closure.Phi (gradedRel false) (gradedRel false)) = Set.univ := by
  apply Set.Subset.antisymm (Set.subset_univ _)
  apply Closure.coinduction
  simpa [false_phi_identity]

def stableModel : StableModel Bool Unit Unit Unit Unit where
  alphaRel := gradedRel
  sigmaRel := gradedRel
  piRel := gradedRel
  rhoRel := gradedRel
  hConv := by simp [gradedRel]
  hConvP := by simp [gradedRel]
  alphaAntitone := gradedRel_antitone
  sigmaAntitone := gradedRel_antitone
  piAntitone := gradedRel_antitone
  rhoAntitone := gradedRel_antitone
  threshold := false
  sig2 := by
    intro w hw Y hY hPost
    cases w
    · simp at hw
    · rcases hY with ⟨c, hc⟩
      simpa [Closure.Phi, Closure.pi_star, Closure.rho_star, gradedRel] using
        hPost hc
  omega := fun _ => false
  kappa := fun _ => {()}
  epsilon := fun _ => {()}
  boundary := {()}
  state := ()
  hSelf := by simpa [false_phi_identity]
  hSMC := by
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, gradedRel]
  hAct := by
    exact ⟨(), by simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, gradedRel]⟩
  hBound := by exact ⟨(), by simp⟩
  nuPhi := {()}
  nuPhi_spec := by
    rw [false_nu]
    ext c
    simp
  contribution := fun _ => {()}
  contribution_spec := by
    intro e
    ext c
    simp [Closure.pi_star, gradedRel]
  externalPredicate := fun _ => False

/-- The one-point stable model has positive structural weight but interprets
the additional predicate as false. -/
theorem countermodel : ∃ model : StableModel Bool Unit Unit Unit Unit,
    ¬ StableTarget model := by
  refine ⟨stableModel, ?_⟩
  intro target
  exact target () (by simp [HasStructuralWeight, viabilityContribution,
    stableModel])

end Countermodel

/-- Ledger-stable name for the theorem 7.3 structure countermodel. -/
theorem countermodel : ∃ model : StableModel Bool Unit Unit Unit Unit,
    ¬ StableTarget model :=
  Countermodel.countermodel

/-- The two §13-5 outlets of the same structural-to-phenomenal gap. -/
inductive StructuralPhenomenalOutlet where
  | tensorToLight
  | valueToMattering
  deriving DecidableEq

/-- The gap kind at stake in §13-5: an extra bridge from third-person structure
to first-person phenomenal fact. -/
inductive GapKind where
  | structuralToPhenomenal
  deriving DecidableEq

/-- Classify each outlet by the kind of gap it opens. -/
def outletGapKind : StructuralPhenomenalOutlet → GapKind
  | .tensorToLight => .structuralToPhenomenal
  | .valueToMattering => .structuralToPhenomenal

/-- `𝐓 → light` and `𝐕 → mattering` are distinct outlets but the same
structural-to-phenomenal gap kind. -/
theorem tensor_and_value_outlets_share_gap_kind :
    outletGapKind StructuralPhenomenalOutlet.tensorToLight =
      outletGapKind StructuralPhenomenalOutlet.valueToMattering := by
  rfl

end Value

end ERIEC
