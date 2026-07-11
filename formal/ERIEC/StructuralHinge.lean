import ERIEC.BridgeFunctor

namespace ERIEC
namespace StructuralHinge

open CategoryTheory
open BridgeFunctor

/-- A structure-preserving isomorphism of complete hinge data. -/
@[ext]
structure CompleteHingeIso
    (X Y : CompleteHingeData.{u, v, w}) where
  onM : X.M ≃ Y.M
  onE : X.E ≃ Y.E
  onC : X.C ≃ Y.C
  map_rho : ∀ c m,
    m ∈ X.rhoRel c ↔ onM m ∈ Y.rhoRel (onC c)
  map_sigma : ∀ e m,
    m ∈ X.sigmaRel e ↔ onM m ∈ Y.sigmaRel (onE e)
  map_kappa : ∀ c, c ∈ X.kappa ↔ onC c ∈ Y.kappa
  map_epsilon : ∀ e, e ∈ X.epsilon ↔ onE e ∈ Y.epsilon

def CompleteHingeIso.refl (X : CompleteHingeData.{u, v, w}) :
    CompleteHingeIso X X where
  onM := Equiv.refl _
  onE := Equiv.refl _
  onC := Equiv.refl _
  map_rho _ _ := Iff.rfl
  map_sigma _ _ := Iff.rfl
  map_kappa _ := Iff.rfl
  map_epsilon _ := Iff.rfl

def CompleteHingeIso.trans {X Y Z : CompleteHingeData.{u, v, w}}
    (f : CompleteHingeIso X Y) (g : CompleteHingeIso Y Z) :
    CompleteHingeIso X Z where
  onM := f.onM.trans g.onM
  onE := f.onE.trans g.onE
  onC := f.onC.trans g.onC
  map_rho c m := (f.map_rho c m).trans (g.map_rho (f.onC c) (f.onM m))
  map_sigma e m :=
    (f.map_sigma e m).trans (g.map_sigma (f.onE e) (f.onM m))
  map_kappa c := (f.map_kappa c).trans (g.map_kappa (f.onC c))
  map_epsilon e := (f.map_epsilon e).trans (g.map_epsilon (f.onE e))

/-- Structural isomorphisms preserve and reflect hinge nonemptiness. -/
theorem CompleteHingeIso.hingeWitness_iff
    {X Y : CompleteHingeData.{u, v, w}} (f : CompleteHingeIso X Y) :
    X.holds ↔ Y.holds := by
  constructor
  · rintro ⟨m, hmRho, hmSigma⟩
    refine ⟨f.onM m, ?_, ?_⟩
    · rcases (by
        simpa [CompleteHingeData.holds, HingeWitness, Closure.rho_star] using hmRho :
          ∃ c, c ∈ X.kappa ∧ m ∈ X.rhoRel c) with ⟨c, hc, hm⟩
      simp [Closure.rho_star]
      exact ⟨f.onC c, (f.map_kappa c).mp hc, (f.map_rho c m).mp hm⟩
    · rcases (by
        simpa [CompleteHingeData.holds, HingeWitness, Adj.sigma_star] using hmSigma :
          ∃ e, e ∈ X.epsilon ∧ m ∈ X.sigmaRel e) with ⟨e, he, hm⟩
      simp [Adj.sigma_star]
      exact ⟨f.onE e, (f.map_epsilon e).mp he, (f.map_sigma e m).mp hm⟩
  · rintro ⟨m, hmRho, hmSigma⟩
    refine ⟨f.onM.symm m, ?_, ?_⟩
    · rcases (by
        simpa [CompleteHingeData.holds, HingeWitness, Closure.rho_star] using hmRho :
          ∃ c, c ∈ Y.kappa ∧ m ∈ Y.rhoRel c) with ⟨c, hc, hm⟩
      simp [Closure.rho_star]
      refine ⟨f.onC.symm c, ?_, ?_⟩
      · exact (f.map_kappa (f.onC.symm c)).mpr (by simpa using hc)
      · exact (f.map_rho (f.onC.symm c) (f.onM.symm m)).mpr (by simpa using hm)
    · rcases (by
        simpa [CompleteHingeData.holds, HingeWitness, Adj.sigma_star] using hmSigma :
          ∃ e, e ∈ Y.epsilon ∧ m ∈ Y.sigmaRel e) with ⟨e, he, hm⟩
      simp [Adj.sigma_star]
      refine ⟨f.onE.symm e, ?_, ?_⟩
      · exact (f.map_epsilon (f.onE.symm e)).mpr (by simpa using he)
      · exact (f.map_sigma (f.onE.symm e) (f.onM.symm m)).mpr (by simpa using hm)

/-- Wrapper carrying the structural-isomorphism category instance. -/
structure StructuralHingeData where
  data : CompleteHingeData.{u, v, w}

instance : Category StructuralHingeData.{u, v, w} where
  Hom X Y := CompleteHingeIso X.data Y.data
  id X := CompleteHingeIso.refl X.data
  comp f g := f.trans g
  id_comp f := by ext <;> rfl
  comp_id f := by ext <;> rfl
  assoc f g h := by ext <;> rfl

/-- Forget a structural isomorphism down to its hinge-truth equivalence. -/
def structuralToStrictFunctor :
    StructuralHingeData.{u, v, w} ⥤ StrictHingeData.{u, v, w} where
  obj X := ⟨X.data⟩
  map f := CategoryTheory.homOfLE f.hingeWitness_iff
  map_id _ := Subsingleton.elim _ _
  map_comp _ _ := Subsingleton.elim _ _

/-- The requested strict bridge on the category of complete structural
isomorphisms, landing in the actual Hilbert intertwiner category. -/
noncomputable def structuralHingeHilbertFunctor :
    StructuralHingeData.{u, v, w} ⥤
      HilbertIntertwiner.EndomorphismObject (EuclideanSpace ℝ (Fin 1)) :=
  structuralToStrictFunctor ⋙ strictHingeHilbertFunctor

theorem structuralHingeHilbertFunctor_nontrivial_iff
    (X : StructuralHingeData.{u, v, w}) :
    World.WldNontrivial (structuralHingeHilbertFunctor.obj X).op ↔
      X.data.holds :=
  strictHingeHilbertFunctor_nontrivial_iff ⟨X.data⟩

end StructuralHinge
end ERIEC
