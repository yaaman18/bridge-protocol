import ERIEC.Wager.Independence
import Mathlib.Data.Fintype.Card

namespace ERIEC
namespace Wager

/-- The true witness family for every richness threshold: the hinge has
exactly `k0` actions. -/
def richImpl (k0 : ℕ) : FrozenImpl (Fin k0) Unit Unit Unit where
  core := {
    alpha := fun _ => Set.univ
    sigma := fun _ => Set.univ
    pi := fun _ => Set.univ
    rho := fun _ => Set.univ
  }
  dc := fun _ => True
  nontrivial := True
  positiveValue := fun _ _ => True
  consciousHinge := fun _ => 0 < k0
  hinge := fun _ => Finset.univ
  step := fun _ _ => True

theorem richImpl_W5 (k0 : ℕ) : W5 (richImpl k0) k0 := by
  intro s _
  simp [richImpl]

/-- The one-action false witness, shared by all nontrivial thresholds. -/
def poorImpl : FrozenImpl Unit Unit Unit Unit := consistentImpl

theorem poorImpl_not_W5 (k0 : ℕ) (hk : 2 ≤ k0) : ¬ W5 poorImpl k0 := by
  intro h
  have hle := h () (by trivial)
  simp [poorImpl, consistentImpl] at hle
  omega

/-- W-8: a uniform pair of finite witnesses for every `k0 ≥ 2`.
The action types are allowed to vary with the finite model, exactly as in the
parameterized reference-model construction. -/
theorem W5_indep_all (k0 : ℕ) (hk : 2 ≤ k0) :
    W5 (richImpl k0) k0 ∧ ¬ W5 poorImpl k0 :=
  ⟨richImpl_W5 k0, poorImpl_not_W5 k0 hk⟩

end Wager
end ERIEC
