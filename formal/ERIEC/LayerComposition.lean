import ERIEC.StructuralHinge
import ERIEC.ViabilityClosure

namespace ERIEC
namespace LayerComposition

open CategoryTheory
open BridgeFunctor
open StructuralHinge
open ViabilityClosure

/-- Forget the `pi/alpha` legs while retaining exactly the complete hinge data
used by the A-1 classifier. -/
def relationalToHingeData (X : RelationalFrameObject.{u}) :
    CompleteHingeData.{u, u, u} where
  M := X.X
  E := X.X
  C := X.X
  rhoRel := X.frame.rhoRel
  sigmaRel := X.frame.sigmaRel
  kappa := X.frame.kappa
  epsilon := X.frame.epsilon

def relationalFrameIsoToHingeIso {X Y : RelationalFrameObject.{u}}
    (f : RelationalFrameIso X Y) :
    CompleteHingeIso (relationalToHingeData X) (relationalToHingeData Y) where
  onM := f.onX
  onE := f.onX
  onC := f.onX
  map_rho := f.map_rho
  map_sigma := f.map_sigma
  map_kappa := f.map_kappa
  map_epsilon := f.map_epsilon

/-- Middle connecting functor from A-2's explicit relation frames to A-1's
hinge category. -/
def relationalToHingeFunctor :
    RelationalFrameObject.{u} ⥤ StructuralHingeData.{u, u, u} where
  obj X := ⟨relationalToHingeData X⟩
  map f := relationalFrameIsoToHingeIso f
  map_id _ := by apply CompleteHingeIso.ext <;> rfl
  map_comp _ _ := by apply CompleteHingeIso.ext <;> rfl

/-- In the A-2 image, hinge nonemptiness is exactly nonemptiness of the
viability region.  Step-closedness reduces both hinge legs to that region. -/
theorem viabilityImage_hinge_iff
    (A : OpenEvolution.ViableSystem.{u}) :
    (relationalToHingeData
      (viabilityRelationalFunctor.obj ⟨A⟩)).holds ↔
      (viableSet A).Nonempty := by
  change HingeWitness
      (reflexiveStepRel A.toOpenSystem)
      (reflexiveStepRel A.toOpenSystem)
      (viableSet A) (viableSet A) ↔ (viableSet A).Nonempty
  simp only [HingeWitness]
  rw [rhoStar_reflexiveStep_eq_successorClosure,
    sigmaStar_reflexiveStep_eq_successorClosure, viable_fixed]
  simp

/-- Implemented three-layer path: viable open systems → relation frames →
hinge data → Hilbert intertwiners. -/
noncomputable def viableToHilbertFunctor :
    ViableCategoryObject.{u} ⥤
      HilbertIntertwiner.EndomorphismObject (EuclideanSpace ℝ (Fin 1)) :=
  viabilityRelationalFunctor ⋙ relationalToHingeFunctor ⋙
    structuralHingeHilbertFunctor

/-- The two parenthesizations of the implemented three-layer path agree. -/
theorem viableToHilbert_comp_assoc :
    (viabilityRelationalFunctor ⋙ relationalToHingeFunctor) ⋙
        structuralHingeHilbertFunctor =
      viabilityRelationalFunctor ⋙
        (relationalToHingeFunctor ⋙ structuralHingeHilbertFunctor) :=
  rfl

/-- Endpoint semantics of the composite: its Hilbert loop is nontrivial
exactly when the viable region is inhabited. -/
theorem viableToHilbert_nontrivial_iff (X : ViableCategoryObject.{u}) :
    World.WldNontrivial (viableToHilbertFunctor.obj X).op ↔
      (viableSet X.system).Nonempty := by
  calc
    World.WldNontrivial (viableToHilbertFunctor.obj X).op ↔
        (relationalToHingeFunctor.obj
          (viabilityRelationalFunctor.obj X)).data.holds :=
      structuralHingeHilbertFunctor_nontrivial_iff _
    _ ↔ (viableSet X.system).Nonempty :=
      viabilityImage_hinge_iff X.system

/-- Two-state viable system used to expose information loss in the composite. -/
def boolOpenSystem : OpenEvolution.OpenSystem where
  Fast := Bool
  Slow := Unit
  Env := Unit
  step := fun _ ↦ ∅

def boolViableSystem : OpenEvolution.ViableSystem where
  toOpenSystem := boolOpenSystem
  viable := fun _ ↦ True
  step_closed := by simp [boolOpenSystem]

def boolViableObject : ViableCategoryObject := ⟨boolViableSystem⟩

def toggleConfig :
    OpenEvolution.Config boolOpenSystem ≃ OpenEvolution.Config boolOpenSystem where
  toFun c := (!c.1, c.2)
  invFun c := (!c.1, c.2)
  left_inv c := by rcases c with ⟨b, u, e⟩; cases b <;> rfl
  right_inv c := by rcases c with ⟨b, u, e⟩; cases b <;> rfl

def boolIdentityIso :
    ViableSystemIso boolViableSystem boolViableSystem :=
  ViableSystemIso.refl _

def boolToggleIso :
    ViableSystemIso boolViableSystem boolViableSystem where
  mapConfig := toggleConfig
  map_step _ _ := by change False ↔ False; simp
  map_viable _ := by simp [boolViableSystem]

theorem boolIdentityIso_ne_boolToggleIso : boolIdentityIso ≠ boolToggleIso := by
  intro h
  have hAt := congrArg
    (fun f : ViableSystemIso boolViableSystem boolViableSystem ↦
      f.mapConfig (false, ((), ()))) h
  change (false, ((), ())) = (true, ((), ())) at hAt
  exact Bool.noConfusion (congrArg Prod.fst hAt)

/-- The composite collapses distinct structural automorphisms to the same
identity intertwiner. -/
theorem viableToHilbert_maps_bool_isos_equal :
    viableToHilbertFunctor.map boolIdentityIso =
      viableToHilbertFunctor.map boolToggleIso := by
  apply HilbertIntertwiner.Hom.ext
  rfl

/-- Hence the implemented path is not faithful, so it cannot serve as one leg
of an information-preserving equivalence/identity loop without extra data. -/
theorem viableToHilbert_not_faithful :
    ¬ Function.Injective
      (fun f : boolViableObject ⟶ boolViableObject ↦
        viableToHilbertFunctor.map f) := by
  intro hInjective
  exact boolIdentityIso_ne_boolToggleIso
    (hInjective viableToHilbert_maps_bool_isos_equal)

theorem no_bool_hom_left_inverse :
    ¬ ∃ recover :
        (viableToHilbertFunctor.obj boolViableObject ⟶
          viableToHilbertFunctor.obj boolViableObject) →
        (boolViableObject ⟶ boolViableObject),
      ∀ f : boolViableObject ⟶ boolViableObject,
        recover (viableToHilbertFunctor.map f) = f := by
  rintro ⟨recover, hrecover⟩
  apply boolIdentityIso_ne_boolToggleIso
  exact (hrecover boolIdentityIso).symm.trans
    ((congrArg recover viableToHilbert_maps_bool_isos_equal).trans
      (hrecover boolToggleIso))

end LayerComposition
end ERIEC
