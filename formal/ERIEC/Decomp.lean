import Mathlib.Data.Sum.Basic

namespace ERIEC

namespace Decomp


def copair {A B C : Type*} (left : A → C) (right : B → C) : Sum A B → C
  | .inl value => left value
  | .inr value => right value

theorem copair_unique {A B C : Type*} (left : A → C) (right : B → C)
    (candidate : Sum A B → C)
    (hleft : ∀ value, candidate (.inl value) = left value)
    (hright : ∀ value, candidate (.inr value) = right value) :
    candidate = copair left right := by
  funext input
  cases input with
  | inl value => exact hleft value
  | inr value => exact hright value

def canonical {A B : Type*} : Sum A B → Sum A B := copair Sum.inl Sum.inr

theorem canonical_eq_id {A B : Type*} : canonical = (id : Sum A B → Sum A B) := by
  funext input
  cases input <;> rfl

def Reducible {A B C : Type*} (observe : Sum A B → C) : Prop :=
  ∃ left : A → C, ∃ right : B → C, observe = copair left right

theorem reducible_all {A B C : Type*} (observe : Sum A B → C) : Reducible observe :=
  ⟨fun value => observe (.inl value), fun value => observe (.inr value),
    copair_unique _ _ observe (fun _ => rfl) (fun _ => rfl)⟩

end Decomp

end ERIEC
