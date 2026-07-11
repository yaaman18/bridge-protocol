import ERIEC.OpenEvolution
import ERIEC.Grading
import ERIEC.Hinge
import Mathlib.CategoryTheory.Core

namespace ERIEC
namespace ViabilityClosure

open OpenEvolution
open CategoryTheory

/-- Reflexive one-step forward closure.  Adding `K` itself aligns forward
viability (`post(K) ⊆ K`) with the post-fixed orientation used by `h₁/h₂`. -/
def successorClosure (A : OpenSystem.{u})
    (K : Set (Config A)) : Set (Config A) :=
  K ∪ {c' | ∃ c ∈ K, c' ∈ A.step c}

theorem successorClosure_monotone (A : OpenSystem.{u}) :
    Monotone (successorClosure A) := by
  intro K L hKL c hc
  rcases hc with hc | ⟨source, hsource, hstep⟩
  · exact Or.inl (hKL hc)
  · exact Or.inr ⟨source, hKL hsource, hstep⟩

theorem subset_successorClosure (A : OpenSystem.{u}) (K : Set (Config A)) :
    K ⊆ successorClosure A K :=
  fun _ hc ↦ Or.inl hc

def viableSet (A : ViableSystem.{u}) : Set (Config A.toOpenSystem) :=
  {c | A.viable c}

theorem successorClosure_viable_subset (A : ViableSystem.{u}) :
    successorClosure A.toOpenSystem (viableSet A) ⊆ viableSet A := by
  rintro c (hc | ⟨source, hsource, hstep⟩)
  · exact hc
  · exact A.step_closed hsource hstep

/-- Forward invariance gives a fixed point of the reflexive successor closure,
not merely the post-fixed half required by `h₁/h₂`. -/
theorem viable_fixed (A : ViableSystem.{u}) :
    successorClosure A.toOpenSystem (viableSet A) = viableSet A :=
  Set.Subset.antisymm (successorClosure_viable_subset A)
    (subset_successorClosure A.toOpenSystem (viableSet A))

/-- Constant rank family generated from an open system's successor closure. -/
def rankedSuccessorClosure (W : Type v) (A : OpenSystem.{u}) :
    Grading.RankedClosure W (Config A) where
  op := fun _ ↦ successorClosure A
  monotone := fun _ ↦ successorClosure_monotone A

/-- Abstract target object carrying the two post-fixed stage families required
by the `h₁ ∧ h₂` interface.  The two channels are kept distinct even when the
canonical viability construction uses the same closure on both. -/
structure ClosureStagePair (W : Type v) (X : Type u) where
  left : Grading.RankedClosure W X
  right : Grading.RankedClosure W X
  stage : W → Set X
  left_postfixed : ∀ w, stage w ⊆ left.op w (stage w)
  right_postfixed : ∀ w, stage w ⊆ right.op w (stage w)

/-- Object map for A-2: a viable open system yields constant rank-indexed
`h₁/h₂` stages. -/
def viabilityClosureImage (W : Type v) (A : ViableSystem.{u}) :
    ClosureStagePair W (Config A.toOpenSystem) where
  left := rankedSuccessorClosure W A.toOpenSystem
  right := rankedSuccessorClosure W A.toOpenSystem
  stage := fun _ ↦ viableSet A
  left_postfixed := fun _ ↦ subset_successorClosure _ _
  right_postfixed := fun _ ↦ subset_successorClosure _ _

theorem viabilityClosureImage_left_fixed (W : Type v)
    (A : ViableSystem.{u}) (w : W) :
    (viabilityClosureImage W A).left.op w
        ((viabilityClosureImage W A).stage w) =
      (viabilityClosureImage W A).stage w :=
  viable_fixed A

theorem viabilityClosureImage_right_fixed (W : Type v)
    (A : ViableSystem.{u}) (w : W) :
    (viabilityClosureImage W A).right.op w
        ((viabilityClosureImage W A).stage w) =
      (viabilityClosureImage W A).stage w :=
  viable_fixed A

/-- Isomorphism of viable transition systems at the configuration level. -/
@[ext]
structure ViableSystemIso (A B : ViableSystem.{u}) where
  mapConfig : Config A.toOpenSystem ≃ Config B.toOpenSystem
  map_step : ∀ c c',
    c' ∈ A.toOpenSystem.step c ↔
      mapConfig c' ∈ B.toOpenSystem.step (mapConfig c)
  map_viable : ∀ c, A.viable c ↔ B.viable (mapConfig c)

def ViableSystemIso.refl (A : ViableSystem.{u}) : ViableSystemIso A A where
  mapConfig := Equiv.refl _
  map_step _ _ := Iff.rfl
  map_viable _ := Iff.rfl

def ViableSystemIso.trans {A B C : ViableSystem.{u}}
    (f : ViableSystemIso A B) (g : ViableSystemIso B C) :
    ViableSystemIso A C where
  mapConfig := f.mapConfig.trans g.mapConfig
  map_step c c' := (f.map_step c c').trans
    (g.map_step (f.mapConfig c) (f.mapConfig c'))
  map_viable c := (f.map_viable c).trans (g.map_viable (f.mapConfig c))

/-- Reflexive successor closure is natural under transition-system isomorphism. -/
theorem successorClosure_natural {A B : ViableSystem.{u}}
    (f : ViableSystemIso A B) (K : Set (Config A.toOpenSystem)) :
    Set.image f.mapConfig (successorClosure A.toOpenSystem K) =
      successorClosure B.toOpenSystem (Set.image f.mapConfig K) := by
  ext y
  constructor
  · rintro ⟨x, hx, rfl⟩
    rcases hx with hx | ⟨source, hsource, hstep⟩
    · exact Or.inl ⟨x, hx, rfl⟩
    · exact Or.inr ⟨f.mapConfig source, ⟨source, hsource, rfl⟩,
        (f.map_step source x).mp hstep⟩
  · intro hy
    rcases hy with ⟨x, hx, rfl⟩ | ⟨source, ⟨pre, hpre, hsource⟩, hstep⟩
    · exact ⟨x, Or.inl hx, rfl⟩
    · subst hsource
      let target := f.mapConfig.symm y
      have hstep' : target ∈ A.toOpenSystem.step pre := by
        apply (f.map_step pre target).mpr
        simpa [target] using hstep
      exact ⟨target, Or.inr ⟨pre, hpre, hstep'⟩, by simp [target]⟩

theorem viableSet_natural {A B : ViableSystem.{u}}
    (f : ViableSystemIso A B) :
    Set.image f.mapConfig (viableSet A) = viableSet B := by
  ext y
  constructor
  · rintro ⟨x, hx, rfl⟩
    exact (f.map_viable x).mp hx
  · intro hy
    change B.viable y at hy
    refine ⟨f.mapConfig.symm y, ?_, by simp⟩
    exact (f.map_viable (f.mapConfig.symm y)).mpr (by simpa using hy)

structure ViableCategoryObject where
  system : ViableSystem.{u}

instance : Category ViableCategoryObject.{u} where
  Hom X Y := ViableSystemIso X.system Y.system
  id X := ViableSystemIso.refl X.system
  comp f g := f.trans g
  id_comp f := by ext <;> rfl
  comp_id f := by ext <;> rfl
  assoc f g h := by ext <;> rfl

/-- The target category retains the source system together with its canonical
closure-stage object. -/
structure ClosureImageObject (W : Type v) where
  system : ViableSystem.{u}

def ClosureImageObject.pair (X : ClosureImageObject W) :
    ClosureStagePair W (Config X.system.toOpenSystem) :=
  viabilityClosureImage W X.system

instance : Category (ClosureImageObject.{v, u} W) where
  Hom X Y := ViableSystemIso X.system Y.system
  id X := ViableSystemIso.refl X.system
  comp f g := f.trans g
  id_comp f := by ext <;> rfl
  comp_id f := by ext <;> rfl
  assoc f g h := by ext <;> rfl

/-- A-2 functor on structural isomorphisms. -/
def viabilityClosureFunctor (W : Type v) :
    ViableCategoryObject.{u} ⥤ ClosureImageObject.{v, u} W where
  obj X := ⟨X.system⟩
  map f := f
  map_id _ := rfl
  map_comp _ _ := rfl

theorem viabilityClosureFunctor_stage_natural (W : Type v)
    {X Y : ViableCategoryObject.{u}} (f : X ⟶ Y) (w : W) :
    Set.image f.mapConfig ((((viabilityClosureFunctor W).obj X).pair).stage w) =
      (((viabilityClosureFunctor W).obj Y).pair).stage w :=
  viableSet_natural f

theorem viabilityClosureFunctor_left_natural (W : Type v)
    {X Y : ViableCategoryObject.{u}} (f : X ⟶ Y) (w : W)
    (K : Set (Config X.system.toOpenSystem)) :
    Set.image f.mapConfig
        (((viabilityClosureFunctor W).obj X).pair.left.op w K) =
      ((viabilityClosureFunctor W).obj Y).pair.left.op w
        (Set.image f.mapConfig K) :=
  successorClosure_natural f K

theorem viabilityClosureFunctor_right_natural (W : Type v)
    {X Y : ViableCategoryObject.{u}} (f : X ⟶ Y) (w : W)
    (K : Set (Config X.system.toOpenSystem)) :
    Set.image f.mapConfig
        (((viabilityClosureFunctor W).obj X).pair.right.op w K) =
      ((viabilityClosureFunctor W).obj Y).pair.right.op w
        (Set.image f.mapConfig K) :=
  successorClosure_natural f K

/-- Identity relation used for the outward legs `pi` and `alpha`. -/
def identityRel (x : X) : Set X := {x}

/-- Relation containing the current configuration and all one-step successors. -/
def reflexiveStepRel (A : OpenSystem.{u}) (c : Config A) : Set (Config A) :=
  {c} ∪ A.step c

theorem phi_reflexiveStep_eq_successorClosure (A : OpenSystem.{u})
    (K : Set (Config A)) :
    Closure.Phi identityRel (reflexiveStepRel A) K = successorClosure A K := by
  ext x
  simp [Closure.Phi, Closure.pi_star, Closure.rho_star, identityRel,
    reflexiveStepRel, successorClosure]
  aesop

theorem tPrime_reflexiveStep_eq_successorClosure (A : OpenSystem.{u})
    (K : Set (Config A)) :
    Hinge.T_prime identityRel (reflexiveStepRel A) K = successorClosure A K := by
  ext x
  simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, identityRel,
    reflexiveStepRel, successorClosure]
  aesop

theorem rhoStar_reflexiveStep_eq_successorClosure (A : OpenSystem.{u})
    (K : Set (Config A)) :
    Closure.rho_star (reflexiveStepRel A) K = successorClosure A K := by
  ext x
  simp [Closure.rho_star, reflexiveStepRel, successorClosure]
  aesop

theorem sigmaStar_reflexiveStep_eq_successorClosure (A : OpenSystem.{u})
    (K : Set (Config A)) :
    Adj.sigma_star (reflexiveStepRel A) K = successorClosure A K := by
  ext x
  simp [Adj.sigma_star, reflexiveStepRel, successorClosure]
  aesop

/-- Relation-level target object realizing both abstract closure channels. -/
structure RelationalClosureFrame (X : Type u) where
  piRel : X → Set X
  rhoRel : X → Set X
  alphaRel : X → Set X
  sigmaRel : X → Set X
  kappa : Set X
  epsilon : Set X
  hSelf : kappa ⊆ Closure.Phi piRel rhoRel kappa
  hSMC : epsilon ⊆ Hinge.T_prime alphaRel sigmaRel epsilon

/-- A viable system mapped into an actual `pi/rho/alpha/sigma` frame. -/
def viabilityRelationalFrame (A : ViableSystem.{u}) :
    RelationalClosureFrame (Config A.toOpenSystem) where
  piRel := identityRel
  rhoRel := reflexiveStepRel A.toOpenSystem
  alphaRel := identityRel
  sigmaRel := reflexiveStepRel A.toOpenSystem
  kappa := viableSet A
  epsilon := viableSet A
  hSelf := by
    rw [phi_reflexiveStep_eq_successorClosure]
    exact subset_successorClosure _ _
  hSMC := by
    rw [tPrime_reflexiveStep_eq_successorClosure]
    exact subset_successorClosure _ _

theorem viabilityRelationalFrame_left_fixed (A : ViableSystem.{u}) :
    Closure.Phi (viabilityRelationalFrame A).piRel
        (viabilityRelationalFrame A).rhoRel
        (viabilityRelationalFrame A).kappa =
      (viabilityRelationalFrame A).kappa := by
  exact (phi_reflexiveStep_eq_successorClosure A.toOpenSystem _).trans
    (viable_fixed A)

theorem viabilityRelationalFrame_right_fixed (A : ViableSystem.{u}) :
    Hinge.T_prime (viabilityRelationalFrame A).alphaRel
        (viabilityRelationalFrame A).sigmaRel
        (viabilityRelationalFrame A).epsilon =
      (viabilityRelationalFrame A).epsilon := by
  exact (tPrime_reflexiveStep_eq_successorClosure A.toOpenSystem _).trans
    (viable_fixed A)

/-- Bundled relation-level target object with varying carrier. -/
structure RelationalFrameObject where
  X : Type u
  frame : RelationalClosureFrame X

/-- Structure-preserving isomorphism of relation-level closure frames. -/
@[ext]
structure RelationalFrameIso (X Y : RelationalFrameObject.{u}) where
  onX : X.X ≃ Y.X
  map_pi : ∀ x y, y ∈ X.frame.piRel x ↔ onX y ∈ Y.frame.piRel (onX x)
  map_rho : ∀ x y, y ∈ X.frame.rhoRel x ↔ onX y ∈ Y.frame.rhoRel (onX x)
  map_alpha : ∀ x y,
    y ∈ X.frame.alphaRel x ↔ onX y ∈ Y.frame.alphaRel (onX x)
  map_sigma : ∀ x y,
    y ∈ X.frame.sigmaRel x ↔ onX y ∈ Y.frame.sigmaRel (onX x)
  map_kappa : ∀ x, x ∈ X.frame.kappa ↔ onX x ∈ Y.frame.kappa
  map_epsilon : ∀ x, x ∈ X.frame.epsilon ↔ onX x ∈ Y.frame.epsilon

def RelationalFrameIso.refl (X : RelationalFrameObject.{u}) :
    RelationalFrameIso X X where
  onX := Equiv.refl _
  map_pi _ _ := Iff.rfl
  map_rho _ _ := Iff.rfl
  map_alpha _ _ := Iff.rfl
  map_sigma _ _ := Iff.rfl
  map_kappa _ := Iff.rfl
  map_epsilon _ := Iff.rfl

def RelationalFrameIso.trans {X Y Z : RelationalFrameObject.{u}}
    (f : RelationalFrameIso X Y) (g : RelationalFrameIso Y Z) :
    RelationalFrameIso X Z where
  onX := f.onX.trans g.onX
  map_pi x y := (f.map_pi x y).trans (g.map_pi (f.onX x) (f.onX y))
  map_rho x y := (f.map_rho x y).trans (g.map_rho (f.onX x) (f.onX y))
  map_alpha x y := (f.map_alpha x y).trans
    (g.map_alpha (f.onX x) (f.onX y))
  map_sigma x y := (f.map_sigma x y).trans
    (g.map_sigma (f.onX x) (f.onX y))
  map_kappa x := (f.map_kappa x).trans (g.map_kappa (f.onX x))
  map_epsilon x := (f.map_epsilon x).trans (g.map_epsilon (f.onX x))

instance : Category RelationalFrameObject.{u} where
  Hom := RelationalFrameIso
  id X := RelationalFrameIso.refl X
  comp f g := f.trans g
  id_comp f := by ext <;> rfl
  comp_id f := by ext <;> rfl
  assoc f g h := by ext <;> rfl

def viableIsoToRelationalFrameIso {A B : ViableSystem.{u}}
    (f : ViableSystemIso A B) :
    RelationalFrameIso
      ⟨Config A.toOpenSystem, viabilityRelationalFrame A⟩
      ⟨Config B.toOpenSystem, viabilityRelationalFrame B⟩ where
  onX := f.mapConfig
  map_pi x y := by simp [viabilityRelationalFrame, identityRel]
  map_rho x y := by
    constructor
    · rintro (hxy | hstep)
      · exact Or.inl (by simpa using congrArg f.mapConfig hxy)
      · exact Or.inr ((f.map_step x y).mp hstep)
    · rintro (hxy | hstep)
      · exact Or.inl (f.mapConfig.injective hxy)
      · exact Or.inr ((f.map_step x y).mpr hstep)
  map_alpha x y := by simp [viabilityRelationalFrame, identityRel]
  map_sigma x y := by
    constructor
    · rintro (hxy | hstep)
      · exact Or.inl (by simpa using congrArg f.mapConfig hxy)
      · exact Or.inr ((f.map_step x y).mp hstep)
    · rintro (hxy | hstep)
      · exact Or.inl (f.mapConfig.injective hxy)
      · exact Or.inr ((f.map_step x y).mpr hstep)
  map_kappa x := f.map_viable x
  map_epsilon x := f.map_viable x

/-- Completed A-2 functor into the explicit relation-frame category. -/
def viabilityRelationalFunctor :
    ViableCategoryObject.{u} ⥤ RelationalFrameObject.{u} where
  obj X := ⟨Config X.system.toOpenSystem, viabilityRelationalFrame X.system⟩
  map f := viableIsoToRelationalFrameIso f
  map_id _ := by apply RelationalFrameIso.ext; rfl
  map_comp _ _ := by apply RelationalFrameIso.ext; rfl

theorem viabilityRelationalFunctor_kappa_natural
    {X Y : ViableCategoryObject.{u}} (f : X ⟶ Y) (x : Config X.system.toOpenSystem) :
    x ∈ (viabilityRelationalFunctor.obj X).frame.kappa ↔
      (viabilityRelationalFunctor.map f).onX x ∈
        (viabilityRelationalFunctor.obj Y).frame.kappa :=
  (viabilityRelationalFunctor.map f).map_kappa x

theorem viabilityRelationalFunctor_epsilon_natural
    {X Y : ViableCategoryObject.{u}} (f : X ⟶ Y) (x : Config X.system.toOpenSystem) :
    x ∈ (viabilityRelationalFunctor.obj X).frame.epsilon ↔
      (viabilityRelationalFunctor.map f).onX x ∈
        (viabilityRelationalFunctor.obj Y).frame.epsilon :=
  (viabilityRelationalFunctor.map f).map_epsilon x

end ViabilityClosure
end ERIEC
