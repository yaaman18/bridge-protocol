import Mathlib.Order.Preorder.Finite
import ERIEC.OpenEvolution

namespace ERIEC

namespace OpenEvolution

universe u v w

/-- §19.1: generation is a relation between systems, not an ordinary step
inside one system. -/
abbrev GenEvent := OpenSystem.{u} → OpenSystem.{u} → Prop

/-- Data required by a concrete witness of a generation event. The certificate
predicates are parameters, so this layer does not identify viability with DC. -/
structure GenerationWitness
    (parentSystem childSystem : OpenSystem.{u})
    (Record Heritage : Type v)
    (parentViable : Config parentSystem → Prop)
    (childViable : Config childSystem → Prop)
    (parentHeritage : Config parentSystem → Heritage)
    (childHeritage : Config childSystem → Heritage)
    (heritageRelated : Heritage → Heritage → Prop) where
  parent : Config parentSystem
  child : Config childSystem
  record : Record
  parent_viable : parentViable parent
  child_viable : childViable child
  heritage : heritageRelated (parentHeritage parent) (childHeritage child)

/-- §19.2: a chosen semantic equivalence, supplied by the audit use case. -/
structure SemanticEquivalence where
  rel : OpenSystem.{u} → OpenSystem.{u} → Prop
  refl : ∀ system, rel system system
  symm : ∀ {left right}, rel left right → rel right left
  trans : ∀ {left middle right}, rel left middle → rel middle right → rel left right

/-- A lineage is a sequence of systems connected by genuine generation
events. -/
structure Lineage (generation : GenEvent.{u}) where
  system : Nat → OpenSystem.{u}
  event : ∀ n, generation (system n) (system (n + 1))

namespace Lineage

variable {generation : GenEvent.{u}}

def FreshSem (sem : SemanticEquivalence.{u}) (L : Lineage generation) : Prop :=
  ∀ n, ∃ m, n ≤ m ∧ ∀ k, k < m → ¬ sem.rel (L.system m) (L.system k)

def EventuallyPeriodicSem (sem : SemanticEquivalence.{u})
    (L : Lineage generation) : Prop :=
  ∃ N p, 0 < p ∧ ∀ n, N ≤ n →
    sem.rel (L.system (n + p)) (L.system n)

def Cofinal {Q : Type v} [LT Q]
    (q : OpenSystem.{u} → Q) (L : Lineage generation) : Prop :=
  ∀ bound : Q, ∃ n, bound < q (L.system n)

/-- Every state is semantically represented in any prefix past a point at
which no fresh state can occur. -/
private theorem prefix_covers_of_no_fresh
    (sem : SemanticEquivalence.{u}) (L : Lineage generation)
    (n : Nat)
    (h : ∀ m, n ≤ m → ∃ k, k < m ∧ sem.rel (L.system m) (L.system k)) :
    ∀ m, ∃ k, k ≤ n ∧ sem.rel (L.system m) (L.system k) := by
  intro m
  induction m using Nat.strong_induction_on with
  | h m ih =>
      by_cases hmn : m ≤ n
      · exact ⟨m, hmn, sem.refl _⟩
      · obtain ⟨k, hkm, hmk⟩ := h m (Nat.le_of_lt (Nat.lt_of_not_ge hmn))
        obtain ⟨j, hjn, hkj⟩ := ih k hkm
        exact ⟨j, hjn, sem.trans hmk hkj⟩

/-- Theorem 19.4, first half. Cofinality of a semantic-invariant structural
quantity forces arbitrarily late semantically fresh systems. -/
theorem cofinal_implies_freshSem {Q : Type v} [PartialOrder Q]
    (sem : SemanticEquivalence.{u})
    (L : Lineage generation)
    (q : OpenSystem.{u} → Q)
    (q_invariant : ∀ {left right}, sem.rel left right → q left = q right)
    (hcofinal : Cofinal q L) :
    FreshSem sem L := by
  intro n
  by_contra hnone
  push Not at hnone
  have cover := prefix_covers_of_no_fresh sem L n hnone
  let initialSegment := Finset.range (n + 1)
  have initialSegment_nonempty : initialSegment.Nonempty :=
    ⟨0, by simp [initialSegment]⟩
  obtain ⟨i, hi⟩ := Finset.exists_maximalFor
    (fun k => q (L.system k)) initialSegment initialSegment_nonempty
  obtain ⟨m, him⟩ := hcofinal (q (L.system i))
  obtain ⟨k, hkn, hmk⟩ := cover m
  have hk_mem : k ∈ initialSegment := by
    simp [initialSegment, hkn]
  have qmk : q (L.system m) = q (L.system k) := q_invariant hmk
  have hik : q (L.system i) < q (L.system k) := qmk ▸ him
  have hki : q (L.system k) ≤ q (L.system i) := hi.2 hk_mem hik.le
  exact (not_le_of_gt hik) hki

/-- An eventually periodic lineage has only finitely many semantic classes
after reducing indices modulo its positive period. -/
private theorem eventuallyPeriodic_prefix_covers
    (sem : SemanticEquivalence.{u}) (L : Lineage generation)
    {N p : Nat} (hp : 0 < p)
    (hperiod : ∀ n, N ≤ n →
      sem.rel (L.system (n + p)) (L.system n)) :
    ∀ m, ∃ k, k < N + p ∧ sem.rel (L.system m) (L.system k) := by
  intro m
  induction m using Nat.strong_induction_on with
  | h m ih =>
      by_cases hm : m < N + p
      · exact ⟨m, hm, sem.refl _⟩
      · let n := m - p
        have hnN : N ≤ n := by
          dsimp [n]
          omega
        have hnm : n < m := by
          dsimp [n]
          omega
        have hnp : n + p = m := by
          dsimp [n]
          omega
        obtain ⟨k, hk, hnk⟩ := ih n hnm
        exact ⟨k, hk, sem.trans (hnp ▸ hperiod n hnN) hnk⟩

/-- Theorem 19.4, second half: semantic freshness excludes eventual semantic
periodicity. -/
theorem freshSem_not_eventuallyPeriodicSem
    (sem : SemanticEquivalence.{u})
    (L : Lineage generation)
    (hfresh : FreshSem sem L) :
    ¬ EventuallyPeriodicSem sem L := by
  rintro ⟨N, p, hp, hperiod⟩
  obtain ⟨m, hm, hmFresh⟩ := hfresh (N + p)
  obtain ⟨k, hk, hmk⟩ := eventuallyPeriodic_prefix_covers sem L hp hperiod m
  exact hmFresh k (lt_of_lt_of_le hk hm) hmk

/-- §19.5: existence of a viable, strictly richer generated child. -/
def ProducesRicherSystem {Q : Type v} [LT Q]
    (generation : GenEvent.{u})
    (viable : OpenSystem.{u} → Prop)
    (q : OpenSystem.{u} → Q)
    (system : OpenSystem.{u}) : Prop :=
  viable system → ∃ child,
    generation system child ∧ viable child ∧ q system < q child

end Lineage

end OpenEvolution

end ERIEC
