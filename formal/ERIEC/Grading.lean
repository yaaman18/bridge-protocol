import Mathlib.Order.Basic
import ERIEC.Closure

namespace ERIEC

namespace Grading

universe u v w

/-- A thin rank category is represented by its preorder. -/
structure WCat where
  Obj : Type u
  instPreorder : Preorder Obj

attribute [instance] WCat.instPreorder

/-- Rank-indexed relations restrict contravariantly along the rank order. -/
structure RelPresheaf (W : WCat.{u}) (A : Type v) (B : Type w) where
  rel : W.Obj → A → B → Prop
  restrict : ∀ {low high}, low ≤ high → ∀ {a b}, rel high a b → rel low a b

def AntitoneRelation {W : Type u} [Preorder W] {A : Type v} {B : Type w}
    (rel : W → A → B → Prop) : Prop :=
  ∀ {low high}, low ≤ high → ∀ {a b}, rel high a b → rel low a b

/-- The presheaf law for a constant carrier is exactly antitonicity of its
rank-indexed relation. -/
theorem constPresheaf_iff_antitone {W : Type u} [Preorder W]
    {A : Type v} {B : Type w} (rel : W → A → B → Prop) :
    (∃ P : RelPresheaf ⟨W, inferInstance⟩ A B, P.rel = rel) ↔
      AntitoneRelation rel := by
  constructor
  · rintro ⟨P, rfl⟩
    exact P.restrict
  · intro h
    exact ⟨⟨rel, h⟩, rfl⟩

structure RankedClosure (W : Type u) (C : Type v) where
  op : W → Set C → Set C
  monotone : ∀ w, Monotone (op w)

def sieve {W : Type u} {C : Type v} (family : RankedClosure W C)
    (Y : Set C) : Set W :=
  {w | Y ⊆ family.op w Y}

def w_crit {W : Type u} [CompleteLinearOrder W] {C : Type v}
    (family : RankedClosure W C) (Y : Set C) : W :=
  sSup (sieve family Y)

def sig2 {W : Type u} [LT W] {C : Type v}
    (family : RankedClosure W C) (threshold : W) : Prop :=
  ∀ w, threshold < w → ∀ Y : Set C, Y.Nonempty → ¬ Y ⊆ family.op w Y

theorem nuPhi_empty_above {W : Type u} [LT W] {C : Type v}
    (family : RankedClosure W C) (threshold w : W)
    (hsig2 : sig2 family threshold) (habove : threshold < w) :
    Closure.nu (family.op w) = ∅ := by
  apply Set.Subset.antisymm
  · intro c hc
    have hpost : Closure.nu (family.op w) ⊆
        family.op w (Closure.nu (family.op w)) :=
      Closure.nu_postfixed (family.monotone w)
    exact (hsig2 w habove (Closure.nu (family.op w)) ⟨c, hc⟩ hpost).elim
  · exact Set.empty_subset _

end Grading

end ERIEC
