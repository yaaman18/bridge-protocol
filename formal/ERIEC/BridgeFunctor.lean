import ERIEC.Hinge
import ERIEC.HilbertIntertwiner
import ERIEC.InterfaceLinearization
import ERIEC.World
import Mathlib.CategoryTheory.Category.Preorder

namespace ERIEC
namespace BridgeFunctor

open InterfaceLinearization
open CategoryTheory

/-- The hinge-existence predicate isolated from a complete frame. -/
def HingeWitness {M E C : Type*}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : Set C) (epsilon : Set E) : Prop :=
  (Closure.rho_star rhoRel kappa ∩ Adj.sigma_star sigmaRel epsilon).Nonempty

/-- A classifier that sees only `alphaRel` would have to assign the same hinge
truth value to every completion sharing that relation. -/
def AlphaOnlyClassifiesHinge {M E C : Type*}
    (classify : (M → Set E) → Prop) : Prop :=
  ∀ (alphaRel : M → Set E) (rhoRel : C → Set M)
    (sigmaRel : E → Set M) (kappa : Set C) (epsilon : Set E),
    HingeWitness rhoRel sigmaRel kappa epsilon ↔ classify alphaRel

/-- No classifier depending only on the action-to-sensation relation can
recover hinge nonemptiness for all completions.  Two one-point completions
with the same `alphaRel` but full versus empty `rhoRel` are a counterexample. -/
theorem no_alphaOnly_hinge_classifier :
    ¬ ∃ classify : (Unit → Set Unit) → Prop,
      AlphaOnlyClassifiesHinge (C := Unit) classify := by
  rintro ⟨classify, hclassify⟩
  let alphaRel : Unit → Set Unit := fun _ ↦ Set.univ
  let rhoFull : Unit → Set Unit := fun _ ↦ Set.univ
  let rhoEmpty : Unit → Set Unit := fun _ ↦ ∅
  let sigmaRel : Unit → Set Unit := fun _ ↦ Set.univ
  let carrier : Set Unit := Set.univ
  have hFull : HingeWitness rhoFull sigmaRel carrier carrier := by
    refine ⟨(), ?_⟩
    simp [HingeWitness, Closure.rho_star, Adj.sigma_star, rhoFull, sigmaRel, carrier]
  have hEmpty : ¬ HingeWitness rhoEmpty sigmaRel carrier carrier := by
    rintro ⟨x, hx⟩
    have hrho : x ∈ Closure.rho_star rhoEmpty carrier := hx.1
    simp [Closure.rho_star, rhoEmpty] at hrho
  have hSameFull := hclassify alphaRel rhoFull sigmaRel carrier carrier
  have hSameEmpty := hclassify alphaRel rhoEmpty sigmaRel carrier carrier
  exact hEmpty (hSameEmpty.mpr (hSameFull.mp hFull))

/-- The unnormalized Gram candidate attached to a finite relation. -/
noncomputable def relationGram {M E : Type*} [Fintype E]
    (rel : M → Set E) : Matrix M M ℝ :=
  (relationMatrix rel).transpose * relationMatrix rel

/-- Matrix-level nontrivial fixed direction. -/
def MatrixFixedNontrivial {M : Type*} [Fintype M]
    (L : Matrix M M ℝ) : Prop :=
  ∃ x : M → ℝ, x ≠ 0 ∧ L.mulVec x = x

/-- The raw `MᵀM` bridge candidate does not derive world nontriviality from a
nonempty hinge: one action incident to both Boolean effects gives Gram value
`2`, hence no eigenvalue-one fixed direction. -/
theorem raw_gram_bridge_counterexample :
    ∃ (alphaRel : Unit → Set Bool) (rhoRel : Unit → Set Unit)
      (sigmaRel : Bool → Set Unit) (kappa : Set Unit) (epsilon : Set Bool),
      HingeWitness rhoRel sigmaRel kappa epsilon ∧
        ¬ MatrixFixedNontrivial (relationGram alphaRel) := by
  let alphaRel : Unit → Set Bool := fun _ ↦ Set.univ
  let rhoRel : Unit → Set Unit := fun _ ↦ Set.univ
  let sigmaRel : Bool → Set Unit := fun _ ↦ Set.univ
  let kappa : Set Unit := Set.univ
  let epsilon : Set Bool := Set.univ
  refine ⟨alphaRel, rhoRel, sigmaRel, kappa, epsilon, ?_, ?_⟩
  · refine ⟨(), ?_⟩
    simp [HingeWitness, Closure.rho_star, Adj.sigma_star, rhoRel, sigmaRel, kappa,
      epsilon]
  · rintro ⟨x, hx, hfixed⟩
    have hu := congrFun hfixed ()
    simp [relationGram, relationMatrix, Matrix.mul_apply, Matrix.mulVec, alphaRel] at hu
    have hu0 : x () = 0 := by linarith
    apply hx
    funext u
    cases u
    exact hu0

/-- Object part of a hinge-classifying bridge.  It uses the complete hinge
data, not merely `alphaRel`: a nonempty hinge is sent to the identity loop on
the one-dimensional Hilbert space, and an empty hinge to the zero loop.

This is a logical classifier.  It does not claim that the selected loop is a
Jacobian-derived physical world loop. -/
noncomputable def hingeClassifyingLoop {M E C : Type*}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : Set C) (epsilon : Set E) :
    EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1) := by
  classical
  exact if HingeWitness rhoRel sigmaRel kappa epsilon then
      ContinuousLinearMap.id ℝ _
    else 0

/-- The classifier object map has exactly the requested truth condition:
world nontriviality is equivalent to hinge nonemptiness. -/
theorem hingeClassifyingLoop_nontrivial_iff {M E C : Type*}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : Set C) (epsilon : Set E) :
    World.WldNontrivial
        (hingeClassifyingLoop rhoRel sigmaRel kappa epsilon) ↔
      HingeWitness rhoRel sigmaRel kappa epsilon := by
  classical
  by_cases hHinge : HingeWitness rhoRel sigmaRel kappa epsilon
  · refine ⟨fun _ ↦ hHinge, fun _ ↦ ?_⟩
    let x : EuclideanSpace ℝ (Fin 1) := EuclideanSpace.single 0 1
    refine ⟨x, ?_, ?_⟩
    · intro hx
      simpa [x] using hx
    · simp [World.WorldFixedVector, hingeClassifyingLoop, hHinge]
  · refine ⟨?_, fun h ↦ (hHinge h).elim⟩
    rintro ⟨x, hx0, hfix⟩
    have hx : x = 0 := by
      simpa [World.WorldFixedVector, hingeClassifyingLoop, hHinge] using hfix.symm
    exact (hx0 hx).elim

/-- A forward hinge arrow preserves existence of a hinge witness. -/
def HingeForward (source target : Prop) : Prop := source → target

theorem hingeForward_id (source : Prop) : HingeForward source source :=
  fun h ↦ h

theorem hingeForward_comp {source middle target : Prop}
    (f : HingeForward source middle) (g : HingeForward middle target) :
    HingeForward source target :=
  fun h ↦ g (f h)

/-- Forward preservation of the hinge induces a lax Hilbert-layer arrow:
the classifying loop cannot decrease its action norm.  Equality is not claimed
for an empty-to-nonempty arrow. -/
theorem hingeClassifyingLoop_lax
    {M₁ E₁ C₁ M₂ E₂ C₂ : Type*}
    (rho₁ : C₁ → Set M₁) (sigma₁ : E₁ → Set M₁)
    (kappa₁ : Set C₁) (epsilon₁ : Set E₁)
    (rho₂ : C₂ → Set M₂) (sigma₂ : E₂ → Set M₂)
    (kappa₂ : Set C₂) (epsilon₂ : Set E₂)
    (hForward : HingeForward
      (HingeWitness rho₁ sigma₁ kappa₁ epsilon₁)
      (HingeWitness rho₂ sigma₂ kappa₂ epsilon₂))
    (x : EuclideanSpace ℝ (Fin 1)) :
    ‖hingeClassifyingLoop rho₁ sigma₁ kappa₁ epsilon₁ x‖ ≤
      ‖hingeClassifyingLoop rho₂ sigma₂ kappa₂ epsilon₂ x‖ := by
  classical
  by_cases h₁ : HingeWitness rho₁ sigma₁ kappa₁ epsilon₁
  · have h₂ := hForward h₁
    simp [hingeClassifyingLoop, h₁, h₂]
  · simp [hingeClassifyingLoop, h₁]

/-- Complete object-layer data needed to decide the hinge predicate. -/
structure CompleteHingeData where
  M : Type u
  E : Type v
  C : Type w
  rhoRel : C → Set M
  sigmaRel : E → Set M
  kappa : Set C
  epsilon : Set E

def CompleteHingeData.holds (X : CompleteHingeData.{u, v, w}) : Prop :=
  HingeWitness X.rhoRel X.sigmaRel X.kappa X.epsilon

/-- The source thin category: arrows preserve hinge nonemptiness. -/
instance : Preorder CompleteHingeData.{u, v, w} where
  le X Y := HingeForward X.holds Y.holds
  le_refl X := hingeForward_id X.holds
  le_trans _ _ _ f g := hingeForward_comp f g

/-- An object in the thin classifier category.  Its Hilbert operator is
determined by `live`, while arrows are forward implications. -/
structure ClassifyingLoopObject where
  live : Prop

instance : Preorder ClassifyingLoopObject where
  le X Y := HingeForward X.live Y.live
  le_refl X := hingeForward_id X.live
  le_trans _ _ _ f g := hingeForward_comp f g

noncomputable def ClassifyingLoopObject.loop (X : ClassifyingLoopObject) :
    EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1) := by
  classical
  exact if X.live then ContinuousLinearMap.id ℝ _ else 0

def hingeClassifierObject (X : CompleteHingeData.{u, v, w}) :
    ClassifyingLoopObject :=
  ⟨X.holds⟩

theorem hingeClassifierObject_monotone :
    Monotone (hingeClassifierObject :
      CompleteHingeData.{u, v, w} → ClassifyingLoopObject) :=
  fun _ _ h ↦ h

/-- Genuine functor packaging of the logical classifier between thin
preorder categories.  The target ordering realizes the lax norm law above. -/
def hingeClassifierFunctor :
    CompleteHingeData.{u, v, w} ⥤ ClassifyingLoopObject :=
  hingeClassifierObject_monotone.functor

theorem hingeClassifierFunctor_nontrivial_iff
    (X : CompleteHingeData.{u, v, w}) :
    World.WldNontrivial (hingeClassifierFunctor.obj X).loop ↔ X.holds := by
  classical
  change World.WldNontrivial
      (hingeClassifyingLoop X.rhoRel X.sigmaRel X.kappa X.epsilon) ↔ X.holds
  simpa [CompleteHingeData.holds] using
    (hingeClassifyingLoop_nontrivial_iff
      X.rhoRel X.sigmaRel X.kappa X.epsilon)

/-- A separate source type for strict arrows, avoiding an overlapping category
instance with the forward/lax preorder on `CompleteHingeData`. -/
structure StrictHingeData where
  data : CompleteHingeData.{u, v, w}

instance : Preorder StrictHingeData.{u, v, w} where
  le X Y := X.data.holds ↔ Y.data.holds
  le_refl _ := Iff.rfl
  le_trans _ _ _ f g := f.trans g

/-- Target objects for the strict groupoid fragment. -/
structure StrictClassifyingLoopObject where
  live : Prop

instance : Preorder StrictClassifyingLoopObject where
  le X Y := X.live ↔ Y.live
  le_refl _ := Iff.rfl
  le_trans _ _ _ f g := f.trans g

noncomputable def StrictClassifyingLoopObject.loop
    (X : StrictClassifyingLoopObject) :
    EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1) := by
  classical
  exact if X.live then ContinuousLinearMap.id ℝ _ else 0

def strictHingeClassifierObject (X : StrictHingeData.{u, v, w}) :
    StrictClassifyingLoopObject :=
  ⟨X.data.holds⟩

theorem strictHingeClassifierObject_monotone :
    Monotone (strictHingeClassifierObject :
      StrictHingeData.{u, v, w} → StrictClassifyingLoopObject) :=
  fun _ _ h ↦ h

/-- On the reversible fragment, the classifier is a strict functor. -/
def strictHingeClassifierFunctor :
    StrictHingeData.{u, v, w} ⥤ StrictClassifyingLoopObject :=
  strictHingeClassifierObject_monotone.functor

/-- A strict source arrow makes the selected Hilbert loops equal. -/
theorem strictHingeClassifier_loop_eq
    {X Y : StrictHingeData.{u, v, w}} (h : X ≤ Y) :
    (strictHingeClassifierFunctor.obj X).loop =
      (strictHingeClassifierFunctor.obj Y).loop := by
  classical
  by_cases hx : X.data.holds
  · have hy : Y.data.holds := h.mp hx
    simp [StrictClassifyingLoopObject.loop, strictHingeClassifierFunctor,
      strictHingeClassifierObject, hx, hy]
  · have hy : ¬Y.data.holds := fun hY ↦ hx (h.mpr hY)
    simp [StrictClassifyingLoopObject.loop, strictHingeClassifierFunctor,
      strictHingeClassifierObject, hx, hy]

/-- Therefore the identity continuous linear map is an intertwiner on every
strict classifier arrow. -/
theorem strictHingeClassifier_identity_intertwines
    {X Y : StrictHingeData.{u, v, w}} (h : X ≤ Y) :
    (strictHingeClassifierFunctor.obj Y).loop.comp
        (ContinuousLinearMap.id ℝ _) =
      (ContinuousLinearMap.id ℝ _).comp
        (strictHingeClassifierFunctor.obj X).loop := by
  rw [ContinuousLinearMap.comp_id, ContinuousLinearMap.id_comp]
  exact (strictHingeClassifier_loop_eq h).symm

/-- The strict classifier packaged into the actual category whose morphisms
are bounded linear intertwiners. -/
noncomputable def strictHingeHilbertFunctor :
    StrictHingeData.{u, v, w} ⥤
      HilbertIntertwiner.EndomorphismObject
        (EuclideanSpace ℝ (Fin 1)) where
  obj X := ⟨(strictHingeClassifierFunctor.obj X).loop⟩
  map {X Y} f :=
    { map := ContinuousLinearMap.id ℝ _
      intertwines := strictHingeClassifier_identity_intertwines
        (CategoryTheory.leOfHom f) }
  map_id _ := by apply HilbertIntertwiner.Hom.ext; rfl
  map_comp _ _ := by apply HilbertIntertwiner.Hom.ext; simp

theorem strictHingeHilbertFunctor_nontrivial_iff
    (X : StrictHingeData.{u, v, w}) :
    World.WldNontrivial (strictHingeHilbertFunctor.obj X).op ↔
      X.data.holds := by
  change World.WldNontrivial
      (strictHingeClassifierFunctor.obj X).loop ↔ X.data.holds
  exact hingeClassifierFunctor_nontrivial_iff X.data

end BridgeFunctor
end ERIEC
