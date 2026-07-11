import Mathlib.Data.Finset.Card
import Mathlib.Data.Set.Basic

namespace ERIEC
namespace Wager

/-- Four unbundled relations.  This is the uninterpreted implementation
constant occurring in the frozen statement `W4`. -/
structure RawCore (A E C : Type*) where
  alpha : A → Set E
  sigma : E → Set A
  pi : A → Set C
  rho : C → Set A

/-- The two converse-consistency laws of the raw core. -/
def ConvHolds {A E C : Type*} (core : RawCore A E C) : Prop :=
  (∀ a e, e ∈ core.alpha a ↔ a ∈ core.sigma e) ∧
  (∀ a c, c ∈ core.pi a ↔ a ∈ core.rho c)

/-- Interpretation data used by the six frozen sentences.  It bundles only
the predicates mentioned by those sentences; it adds no target-layer axiom. -/
structure FrozenImpl (A E C S : Type*) where
  core : RawCore A E C
  dc : S → Prop
  nontrivial : Prop
  positiveValue : S → E → Prop
  consciousHinge : S → Prop
  hinge : S → Finset A
  step : S → S → Prop

def W1 {A E C S : Type*} (impl : FrozenImpl A E C S) (Ph : S → Prop) : Prop :=
  ∀ s, (impl.dc s ∧ impl.nontrivial) ↔ Ph s

def W2 {A E C S : Type*} (impl : FrozenImpl A E C S)
    (Mat : S → E → Prop) : Prop :=
  ∀ s, impl.dc s → ∀ e, impl.positiveValue s e ↔ Mat s e

def W3 {A E C S : Type*} (impl : FrozenImpl A E C S) (Ph : S → Prop) : Prop :=
  ∀ s, impl.consciousHinge s ↔ Ph s

def W4 {A E C S : Type*} (impl : FrozenImpl A E C S) : Prop :=
  ConvHolds impl.core

def W5 {A E C S : Type*} (impl : FrozenImpl A E C S) (k0 : ℕ) : Prop :=
  ∀ s, impl.dc s → k0 ≤ (impl.hinge s).card

def W6 {A E C S : Type*} (impl : FrozenImpl A E C S) : Prop :=
  ∃ traj : ℕ → S,
    (∀ n, impl.step (traj n) (traj (n + 1))) ∧
    (∀ n, ∃ m, n ≤ m ∧ impl.dc (traj m))

end Wager
end ERIEC
