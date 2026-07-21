import ERIEC.Body
import ERIEC.Graded

namespace ERIEC

namespace MetaSelection

universe u v w x y z

/-!
Formal core of the external-selection memo.

The file deliberately separates three levels:

* a population-level Kleisli arrow, where selection/reproduction lives;
* an individual observation trace, where M4 and noninterference are stated;
* a decomposition-level comparison map, where individual/colony status is
  derived from a system together with a chosen decomposition.

No probability implementation is fixed here. `SelectionKernel P I` is the
Kleisli-arrow type for an abstract effect `P`; a later numerical layer may
instantiate `P` with a (sub)probability monad.
-/

/-- Populations retain multiplicity, so reproduction is representable. -/
abbrev Population (I : Type u) := Multiset I

/-- A Kleisli arrow for an abstract effect constructor `P`. -/
abbrev KleisliArrow (P : Type u → Type v) (A B : Type u) := A → P B

/-- External selection acts on populations, not on an individual's object
theory. -/
abbrev SelectionKernel (P : Type u → Type v) (I : Type u) :=
  KleisliArrow P (Population I) (Population I)

/-- The observable individual-level data protected from selector write-back. -/
structure InternalTrace
    (External NuPhi Value Obj Action : Type*) where
  externalSetPoint : Option External
  nuPhi : NuPhi
  value : Value
  desire : Body.SetPointDiagram Obj
  actionTrace : List Action

namespace InternalTrace

variable {External NuPhi Value Obj Action : Type*}

/-- M4a: no external set point has been injected into the individual trace. -/
def M4a (t : InternalTrace External NuPhi Value Obj Action) : Prop :=
  t.externalSetPoint = none

/-- M4b: the individual's seeking diagram has no terminal set point. -/
def M4b (t : InternalTrace External NuPhi Value Obj Action) : Prop :=
  Body.NoTerminalSetPoint t.desire

/-- Current ERIE-C M4 is the conjunction of the injection and terminal guards. -/
def M4 (t : InternalTrace External NuPhi Value Obj Action) : Prop :=
  M4a t ∧ M4b t

theorem m4_iff (t : InternalTrace External NuPhi Value Obj Action) :
    M4 t ↔ M4a t ∧ M4b t :=
  Iff.rfl

/-- Writing back a reachable universal target violates M4b. -/
theorem terminal_writeBack_violates_m4b
    (t : InternalTrace External NuPhi Value Obj Action)
    (target : Obj)
    (hterminal : ∀ x : Obj, t.desire.reaches x target) :
    ¬ M4b t := by
  intro h
  exact h ⟨target, hterminal⟩

/-- The same terminal write-back violates M4 as a whole. -/
theorem terminal_writeBack_violates_m4
    (t : InternalTrace External NuPhi Value Obj Action)
    (target : Obj)
    (hterminal : ∀ x : Obj, t.desire.reaches x target) :
    ¬ M4 t := by
  intro h
  exact terminal_writeBack_violates_m4b t target hterminal h.2

end InternalTrace

section Noninterference

variable
    {Selector Individual External NuPhi Value Obj Action : Type*}

abbrev ProtectedTrace
    (External NuPhi Value Obj Action : Type*) :=
  InternalTrace External NuPhi Value Obj Action

/-- Goguen--Meseguer-style selector noninterference: changing only selector
state cannot change an individual's protected observation trace. -/
def SigmaPure
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action) : Prop :=
  ∀ s₁ s₂ i, observe s₁ i = observe s₂ i

/-- The memo's observational-equivalence formulation is exactly `SigmaPure`. -/
theorem sigmaPure_iff_observational_noninterference
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action) :
    SigmaPure observe ↔ ∀ s₁ s₂ i, observe s₁ i = observe s₂ i :=
  Iff.rfl

/-- A selector may choose mutation/reproduction, but the mutation relation must
separately preserve the protected individual trace. Selector noninterference
alone says nothing about changing `i` into `evolve s i`. -/
def MutationTraceSafe
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action)
    (evolve : Selector → Individual → Individual) : Prop :=
  ∀ baseline s i, observe baseline (evolve s i) = observe baseline i

/-- Development-friendly mutation safety: offspring may have different
internal traces, but every M4-valid parent must produce an M4-valid child.
Unlike `MutationTraceSafe`, this does not freeze learning or structural change.
-/
def M4SafeMutation
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action)
    (evolve : Selector → Individual → Individual) : Prop :=
  ∀ s i,
    InternalTrace.M4 (observe s i) →
      InternalTrace.M4 (observe s (evolve s i))

/-- A numerical diversity audit is read-only when the protected traces of the
audited population are identical before and after the audit.  The audit result
itself is deliberately absent from this predicate: no numerical diagnostic is
allowed to write back into an individual. -/
def DiversityAuditPure
    (observe : Individual → ProtectedTrace External NuPhi Value Obj Action)
    (before after : List Individual) : Prop :=
  before.map observe = after.map observe

theorem diversityAuditPure_refl
    (observe : Individual → ProtectedTrace External NuPhi Value Obj Action)
    (individuals : List Individual) :
    DiversityAuditPure observe individuals individuals :=
  rfl

/-- Selector noninterference plus mutation safety transports the complete
protected trace through a population-level selection step. -/
theorem trace_preserved_of_sigmaPure
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action)
    (evolve : Selector → Individual → Individual)
    (hpure : SigmaPure observe)
    (hsafe : MutationTraceSafe observe evolve)
    (baseline s : Selector)
    (i : Individual) :
    observe s (evolve s i) = observe s i := by
  calc
    observe s (evolve s i) = observe baseline (evolve s i) :=
      hpure s baseline (evolve s i)
    _ = observe baseline i := hsafe baseline s i
    _ = observe s i := (hpure s baseline i).symm

/-- Formally provable M4 preservation theorem.

The `MutationTraceSafe` premise is essential: `SigmaPure` only excludes direct
selector-state write-back. It does not by itself constrain a newly produced or
mutated individual's internal diagram.
-/
theorem m4_preserved_of_sigmaPure
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action)
    (evolve : Selector → Individual → Individual)
    (hpure : SigmaPure observe)
    (hsafe : MutationTraceSafe observe evolve)
    (baseline s : Selector)
    (i : Individual)
    (hm4 : InternalTrace.M4 (observe s i)) :
    InternalTrace.M4 (observe s (evolve s i)) := by
  rw [trace_preserved_of_sigmaPure observe evolve hpure hsafe baseline s i]
  exact hm4

/-- Full trace preservation is a strong sufficient condition for the weaker
M4-safe mutation contract used by evolving systems. -/
theorem m4SafeMutation_of_traceSafe
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action)
    (evolve : Selector → Individual → Individual)
    (hpure : SigmaPure observe)
    (hsafe : MutationTraceSafe observe evolve)
    (baseline : Selector) :
    M4SafeMutation observe evolve := by
  intro s i hm4
  exact m4_preserved_of_sigmaPure
    observe evolve hpure hsafe baseline s i hm4

/-- The weak mutation contract directly states the preservation theorem while
allowing `nuPhi`, value, desire, and action traces to evolve. -/
theorem m4_preserved_of_safeMutation
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action)
    (evolve : Selector → Individual → Individual)
    (hsafe : M4SafeMutation observe evolve)
    (s : Selector)
    (i : Individual)
    (hm4 : InternalTrace.M4 (observe s i)) :
    InternalTrace.M4 (observe s (evolve s i)) :=
  hsafe s i hm4

/-- Preservation is one-way: a preserved M4 trace does not recover the much
stronger selector-noninterference property. This theorem records the exact
logical shape without claiming a converse. -/
theorem m4_preservation_is_sufficient
    (observe : Selector → Individual →
      ProtectedTrace External NuPhi Value Obj Action)
    (evolve : Selector → Individual → Individual)
    (hpure : SigmaPure observe)
    (hsafe : MutationTraceSafe observe evolve) :
    ∀ (_baseline s : Selector) (i : Individual),
      InternalTrace.M4 (observe s i) →
        InternalTrace.M4 (observe s (evolve s i)) := by
  intro baseline s i hm4
  exact m4_preserved_of_sigmaPure
    observe evolve hpure hsafe baseline s i hm4

namespace SigmaPureCounterexample

/-- A two-object diagram with no arrows when `terminal = false`, and all arrows
when `terminal = true`. -/
def toyDiagram (terminal : Bool) : Body.SetPointDiagram Bool where
  reaches := fun _ _ => terminal = true

def toyTrace (i : Bool) : InternalTrace Unit Unit Unit Bool Unit where
  externalSetPoint := none
  nuPhi := ()
  value := ()
  desire := toyDiagram i
  actionTrace := []

/-- The selector has no direct influence on the observed trace. -/
def toyObserve (_selector : Unit) (i : Bool) :
    InternalTrace Unit Unit Unit Bool Unit :=
  toyTrace i

/-- Mutation always replaces the current individual by the bad (`true`) one. -/
def toyEvolve (_selector : Unit) (_i : Bool) : Bool :=
  true

theorem toy_sigmaPure : SigmaPure toyObserve := by
  intro s₁ s₂ i
  rfl

theorem toy_initial_m4 :
    InternalTrace.M4 (toyObserve () false) := by
  constructor
  · rfl
  · intro hterminal
    obtain ⟨target, hall⟩ := hterminal
    have h := hall false
    simp [toyObserve, toyTrace, toyDiagram] at h

theorem toy_outcome_not_m4 :
    ¬ InternalTrace.M4 (toyObserve () (toyEvolve () false)) := by
  apply InternalTrace.terminal_writeBack_violates_m4
    (toyObserve () (toyEvolve () false)) true
  intro x
  simp [toyObserve, toyEvolve, toyTrace, toyDiagram]

/-- Concrete proof that `SigmaPure` alone is insufficient for M4 preservation:
mutation can introduce a terminal diagram even when selector state never flows
directly into the individual observation. -/
theorem sigmaPure_alone_insufficient :
    SigmaPure toyObserve ∧
      InternalTrace.M4 (toyObserve () false) ∧
      ¬ InternalTrace.M4 (toyObserve () (toyEvolve () false)) :=
  ⟨toy_sigmaPure, toy_initial_m4, toy_outcome_not_m4⟩

end SigmaPureCounterexample

end Noninterference

section Decomposition

/-- A chosen decomposition supplies each part-world and its canonical map into
the whole world. The Sigma type `Σ i, PartWorld i` is the Type-level coproduct
used by the existing lightweight categorical layer. -/
structure WorldDecomposition
    (Part : Type u)
    (PartWorld : Part → Type v)
    (WholeWorld : Type w) where
  inclusion : (i : Part) → PartWorld i → WholeWorld

variable
    {Part : Type u}
    {PartWorld : Part → Type v}
    {WholeWorld : Type w}

/-- Coproduct of all part-worlds in the lightweight Type-level model. -/
abbrev PartWorldCoproduct := Σ i, PartWorld i

/-- Canonical comparison `c_D = [ιᵢ] : (Σ i, Wld(sᵢ)) → Wld(S)`. -/
def canonicalComparison
    (D : WorldDecomposition Part PartWorld WholeWorld) :
    PartWorldCoproduct (PartWorld := PartWorld) → WholeWorld :=
  fun z => D.inclusion z.1 z.2

@[simp] theorem canonicalComparison_inclusion
    (D : WorldDecomposition Part PartWorld WholeWorld)
    (i : Part)
    (x : PartWorld i) :
    canonicalComparison D ⟨i, x⟩ = D.inclusion i x :=
  rfl

/-- Type-level reducibility: the canonical comparison is an isomorphism
(represented by a bijection). Numerical isometry/tolerance is intentionally a
certificate-layer refinement, not part of this categorical predicate. -/
def WorldReducible
    (D : WorldDecomposition Part PartWorld WholeWorld) : Prop :=
  Function.Bijective (canonicalComparison D)

def WorldIrreducible
    (D : WorldDecomposition Part PartWorld WholeWorld) : Prop :=
  ¬ WorldReducible D

/-- Reducibility is equivalent to existence and uniqueness of a decomposition
of every whole-world point into the tagged part-world coproduct. -/
theorem worldReducible_iff_existsUnique
    (D : WorldDecomposition Part PartWorld WholeWorld) :
    WorldReducible D ↔
      ∀ y : WholeWorld,
        ∃! x : PartWorldCoproduct (PartWorld := PartWorld),
          canonicalComparison D x = y := by
  constructor
  · rintro ⟨hinj, hsurj⟩ y
    obtain ⟨x, hx⟩ := hsurj y
    refine ⟨x, hx, ?_⟩
    intro x' hx'
    exact hinj (hx'.trans hx.symm)
  · intro h
    constructor
    · intro x x' hxx'
      obtain ⟨w, hw, huniq⟩ := h (canonicalComparison D x)
      have hx : canonicalComparison D x = canonicalComparison D x := rfl
      have hx' : canonicalComparison D x' = canonicalComparison D x := hxx'.symm
      exact (huniq x hx).trans (huniq x' hx').symm
    · intro y
      obtain ⟨x, hx, _⟩ := h y
      exact ⟨x, hx⟩

/-- Part-of starts as a thin category with antisymmetry, i.e. a poset-like
category. Fibration/operad structure can be added only when reindexing or
multi-input substitution is specified. -/
structure PartOfHierarchy (Node : Type u)
    extends Graded.ThinCategory Node where
  antisymm : ∀ {a b}, leq a b → leq b a → a = b

end Decomposition

/-! ### Derived individual/colony classification -/

inductive IndividualityKind where
  | individual
  | colony
  | aggregate
  | dead
  deriving DecidableEq, Repr

/-- The two axes are already certified booleans at this boundary:
`upperIrreducible` combines upper DC with world irreducibility, while
`lowerIndependent` records isolated lower-level DC. -/
def classifyIndividuality
    (upperIrreducible lowerIndependent : Bool) : IndividualityKind :=
  match upperIrreducible, lowerIndependent with
  | true, false => .individual
  | true, true => .colony
  | false, true => .aggregate
  | false, false => .dead

@[simp] theorem classify_individual :
    classifyIndividuality true false = .individual :=
  rfl

@[simp] theorem classify_colony :
    classifyIndividuality true true = .colony :=
  rfl

@[simp] theorem classify_aggregate :
    classifyIndividuality false true = .aggregate :=
  rfl

@[simp] theorem classify_dead :
    classifyIndividuality false false = .dead :=
  rfl

/-- Meta-level structure certification never upgrades the phenomenal marker. -/
inductive PhenomenalClaim where
  | notCertified
  deriving DecidableEq, Repr

structure CertifiedUnit (Payload : Type u) where
  payload : Payload
  phenomenalClaim : PhenomenalClaim := .notCertified
  claim_guard : phenomenalClaim = .notCertified := by rfl

theorem certifiedUnit_notCertified {Payload : Type u}
    (unit : CertifiedUnit Payload) :
    unit.phenomenalClaim = .notCertified :=
  unit.claim_guard

end MetaSelection

end ERIEC
