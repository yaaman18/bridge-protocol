import ERIEC.MetaSelection

namespace ERIEC

namespace OpenEvolution

universe u v

/-!
Lightweight category of open two-timescale dynamical systems.

The concrete labels "brain", "neural network", "ecosystem", and so on do not
occur in the definitions. They are possible models of the same abstract data:
a fast state, a slow structural state, an environment, and a set-valued next
state relation. Set-valued dynamics subsume relations and partial functions and
can later be refined to supports of probability kernels.
-/

/-- An open dynamical system with fast, slow, and environmental state. -/
structure OpenSystem where
  Fast : Type u
  Slow : Type u
  Env : Type u
  step : Fast × (Slow × Env) → Set (Fast × (Slow × Env))

/-- Complete configuration of an open system. -/
abbrev Config (A : OpenSystem.{u}) := A.Fast × (A.Slow × A.Env)

namespace OpenSystem

/-- A structure-preserving map of open systems. -/
structure Hom (A B : OpenSystem.{u}) where
  mapFast : A.Fast → B.Fast
  mapSlow : A.Slow → B.Slow
  mapEnv : A.Env → B.Env
  commutes : ∀ c : Config A,
    Set.image
      (fun c' : Config A =>
        (mapFast c'.1, (mapSlow c'.2.1, mapEnv c'.2.2)))
      (A.step c) =
    B.step (mapFast c.1, (mapSlow c.2.1, mapEnv c.2.2))

namespace Hom

variable {A B C D : OpenSystem.{u}}

/-- Map a complete configuration componentwise. -/
def mapConfig (f : Hom A B) : Config A → Config B :=
  fun c => (f.mapFast c.1, (f.mapSlow c.2.1, f.mapEnv c.2.2))

theorem commutes' (f : Hom A B) (c : Config A) :
    Set.image f.mapConfig (A.step c) = B.step (f.mapConfig c) :=
  f.commutes c

/-- Identity morphism. -/
def id (A : OpenSystem.{u}) : Hom A A where
  mapFast := _root_.id
  mapSlow := _root_.id
  mapEnv := _root_.id
  commutes := by
    intro c
    simp

/-- Composition of open-system morphisms. -/
def comp (f : Hom A B) (g : Hom B C) : Hom A C where
  mapFast := g.mapFast ∘ f.mapFast
  mapSlow := g.mapSlow ∘ f.mapSlow
  mapEnv := g.mapEnv ∘ f.mapEnv
  commutes := by
    intro c
    change Set.image (fun c' => g.mapConfig (f.mapConfig c')) (A.step c) =
      C.step (g.mapConfig (f.mapConfig c))
    calc
      Set.image (fun c' => g.mapConfig (f.mapConfig c')) (A.step c) =
          Set.image g.mapConfig (Set.image f.mapConfig (A.step c)) := by
            rw [Set.image_image]
      _ = Set.image g.mapConfig (B.step (f.mapConfig c)) := by
            rw [f.commutes']
      _ = C.step (g.mapConfig (f.mapConfig c)) := g.commutes' _

@[ext] theorem ext {f g : Hom A B}
    (hFast : f.mapFast = g.mapFast)
    (hSlow : f.mapSlow = g.mapSlow)
    (hEnv : f.mapEnv = g.mapEnv) : f = g := by
  cases f
  cases g
  cases hFast
  cases hSlow
  cases hEnv
  rfl

theorem id_comp (f : Hom A B) : comp (id A) f = f := by
  apply ext <;> rfl

theorem comp_id (f : Hom A B) : comp f (id B) = f := by
  apply ext <;> rfl

theorem assoc (f : Hom A B) (g : Hom B C) (h : Hom C D) :
    comp (comp f g) h = comp f (comp g h) := by
  apply ext <;> rfl

/-- A morphism maps every reachable source transition to a reachable target
transition. This is the elementwise form of the commuting square. -/
theorem maps_reachable (f : Hom A B) {c c' : Config A}
    (hstep : c' ∈ A.step c) :
    f.mapConfig c' ∈ B.step (f.mapConfig c) := by
  rw [← f.commutes' c]
  exact ⟨c', hstep, rfl⟩

end Hom

/-- Minimal plasticity predicate: at least one reachable transition changes
the slow structural state. It deliberately does not identify any concrete
learning algorithm. -/
def Adaptive (A : OpenSystem.{u}) : Prop :=
  ∃ c c' : Config A, c' ∈ A.step c ∧ c'.2.1 ≠ c.2.1

end OpenSystem

/-- A viability region closed under all ordinary transitions. -/
structure ViableSystem where
  toOpenSystem : OpenSystem.{u}
  viable : Config toOpenSystem → Prop
  step_closed : ∀ {c c' : Config toOpenSystem},
    viable c → c' ∈ toOpenSystem.step c → viable c'

namespace ViableSystem

variable (A : ViableSystem.{u})

theorem reachable_viable {c c' : Config A.toOpenSystem}
    (hc : A.viable c)
    (hstep : c' ∈ A.toOpenSystem.step c) :
    A.viable c' :=
  A.step_closed hc hstep

end ViableSystem

/-- Reproduction is a separate transition relation and must preserve
viability. It may fail, branch, or produce mutated offspring. -/
structure ReplicativeSystem where
  toViableSystem : ViableSystem.{u}
  reproduce : Config toViableSystem.toOpenSystem →
    Set (Config toViableSystem.toOpenSystem)
  offspring_viable : ∀ {parent child},
    toViableSystem.viable parent →
    child ∈ reproduce parent →
    toViableSystem.viable child

namespace ReplicativeSystem

variable (A : ReplicativeSystem.{u})

theorem child_viable {parent child : Config A.toViableSystem.toOpenSystem}
    (hp : A.toViableSystem.viable parent)
    (hc : child ∈ A.reproduce parent) :
    A.toViableSystem.viable child :=
  A.offspring_viable hp hc

end ReplicativeSystem

/-- Evolution adds heredity, genuine variation, and population-level
transition to a replicative system. Selection scores are intentionally absent
from individual dynamics. -/
structure EvolutionarySystem where
  toReplicativeSystem : ReplicativeSystem.{u}
  Heritage : Type v
  heritage : Config toReplicativeSystem.toViableSystem.toOpenSystem → Heritage
  hasVariation : ∃ parent child,
    child ∈ toReplicativeSystem.reproduce parent ∧
      heritage child ≠ heritage parent
  populationStep :
    MetaSelection.Population
        (Config toReplicativeSystem.toViableSystem.toOpenSystem) →
      Set (MetaSelection.Population
        (Config toReplicativeSystem.toViableSystem.toOpenSystem))

namespace EvolutionarySystem

variable (A : EvolutionarySystem.{u, v})

/-- Forgetting heredity and population dynamics recovers reproduction. -/
def forgetEvolution : ReplicativeSystem.{u} :=
  A.toReplicativeSystem

/-- Forgetting reproduction recovers a viable open dynamical system. -/
def forgetReproduction : ViableSystem.{u} :=
  A.toReplicativeSystem.toViableSystem

/-- Ultimate forgetful projection to the common open-system base. -/
def forgetToOpen : OpenSystem.{u} :=
  A.toReplicativeSystem.toViableSystem.toOpenSystem

end EvolutionarySystem

section Richness

variable {R : Type v} [Preorder R]

/-- Reachability contract for open-ended enrichment. This is an additional
assumption, not a consequence of viability or natural selection. -/
def ProducesRicher (A : ReplicativeSystem.{u})
    (richness : Config A.toViableSystem.toOpenSystem → R) : Prop :=
  ∀ parent,
    A.toViableSystem.viable parent →
      ∃ child,
        child ∈ A.reproduce parent ∧
        A.toViableSystem.viable child ∧
        richness parent < richness child

/-- The exact constructive content of `ProducesRicher`: every viable parent
has a reachable, viable, strictly richer child. -/
theorem richer_offspring_reachable
    (A : ReplicativeSystem.{u})
    (richness : Config A.toViableSystem.toOpenSystem → R)
    (hproductive : ProducesRicher A richness)
    (parent : Config A.toViableSystem.toOpenSystem)
    (hparent : A.toViableSystem.viable parent) :
    ∃ child,
      child ∈ A.reproduce parent ∧
      A.toViableSystem.viable child ∧
      richness parent < richness child :=
  hproductive parent hparent

/-- The richness contract implies ordinary productive reproduction. -/
theorem producesRicher_implies_offspring
    (A : ReplicativeSystem.{u})
    (richness : Config A.toViableSystem.toOpenSystem → R)
    (hproductive : ProducesRicher A richness)
    (parent : Config A.toViableSystem.toOpenSystem)
    (hparent : A.toViableSystem.viable parent) :
    (A.reproduce parent).Nonempty := by
  obtain ⟨child, hchild, _, _⟩ := hproductive parent hparent
  exact ⟨child, hchild⟩

end Richness

end OpenEvolution

end ERIEC
