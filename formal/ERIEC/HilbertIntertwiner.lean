import Mathlib.Analysis.InnerProductSpace.PiL2
import Mathlib.CategoryTheory.Core

namespace ERIEC
namespace HilbertIntertwiner

open CategoryTheory

variable (V : Type*) [NormedAddCommGroup V] [NormedSpace ℝ V]

/-- A Hilbert-layer object represented by a bounded endomorphism. -/
structure EndomorphismObject where
  op : V →L[ℝ] V

/-- Intertwiners are the structure-preserving arrows between endomorphisms. -/
@[ext]
structure Hom (X Y : EndomorphismObject V) where
  map : V →L[ℝ] V
  intertwines : Y.op.comp map = map.comp X.op

instance : Category (EndomorphismObject V) where
  Hom := Hom V
  id X :=
    { map := ContinuousLinearMap.id ℝ V
      intertwines := by simp }
  comp f g :=
    { map := g.map.comp f.map
      intertwines := by
        rw [← ContinuousLinearMap.comp_assoc, g.intertwines,
          ContinuousLinearMap.comp_assoc, f.intertwines,
          ← ContinuousLinearMap.comp_assoc] }
  id_comp f := by ext; simp
  comp_id f := by ext; simp
  assoc f g h := by ext; simp

@[simp]
theorem id_map (X : EndomorphismObject V) :
    Hom.map (𝟙 X) = ContinuousLinearMap.id ℝ V :=
  rfl

@[simp]
theorem comp_map {X Y Z : EndomorphismObject V}
    (f : X ⟶ Y) (g : Y ⟶ Z) :
    Hom.map (f ≫ g) = g.map.comp f.map :=
  rfl

end HilbertIntertwiner
end ERIEC
