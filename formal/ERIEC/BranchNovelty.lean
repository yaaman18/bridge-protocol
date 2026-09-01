import Mathlib.Data.Set.Card
import ERIEC.Generation

namespace ERIEC
namespace BranchNovelty

universe u

/-- A branch predicate expressed only through the sensory relation. -/
def BranchSigma {M E : Type u} (sigmaRel : E → Set M) (m : M) : Prop :=
  ∃ e₁ e₂ : E, m ∈ sigmaRel e₁ ∧ m ∈ sigmaRel e₂ ∧ e₁ ≠ e₂

/-- Converse consistency makes the sigma-only and alpha presentations of a
branch equivalent. -/
theorem branchSigma_iff_branch {M E : Type u}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ m e, e ∈ alphaRel m ↔ m ∈ sigmaRel e) (m : M) :
    BranchSigma sigmaRel m ↔ Richness.Branch alphaRel m := by
  constructor
  · rintro ⟨e₁, e₂, he₁, he₂, hne⟩
    exact ⟨e₁, e₂, (hConv m e₁).mpr he₁, (hConv m e₂).mpr he₂, hne⟩
  · rintro ⟨e₁, e₂, he₁, he₂, hne⟩
    exact ⟨e₁, e₂, (hConv m e₁).mp he₁, (hConv m e₂).mp he₂, hne⟩

/-- A DC unit whose action and sensory relations are certified converses.
The observation carries no independent replacement relations. -/
structure BranchObservation where
  M : Type u
  E : Type u
  C : Type u
  S : Type u
  dc : DC M E C S
  hConv : ∀ m e, e ∈ dc.alphaRel m ↔ m ∈ dc.sigmaRel e

/-- A branch observation whose environment type is fixed by the enclosing
certified route. -/
structure SharedBranchObservation (E : Type u) where
  M : Type u
  C : Type u
  S : Type u
  dc : DC M E C S
  hConv : ∀ m e, e ∈ dc.alphaRel m ↔ m ∈ dc.sigmaRel e

def SharedBranchObservation.toBranchObservation {E : Type u}
    (observation : SharedBranchObservation E) : BranchObservation.{u} where
  M := observation.M
  E := E
  C := observation.C
  S := observation.S
  dc := observation.dc
  hConv := observation.hConv

/-- A branch anchor together with its sigma-only branching proof. -/
def BranchCarrier (observation : BranchObservation.{u}) : Type u :=
  {m : observation.M // BranchSigma observation.dc.sigmaRel m}

/-- The sigma-fibre represented by a branch anchor. -/
def BranchFiber (observation : BranchObservation.{u})
    (branch : BranchCarrier observation) : Set observation.E :=
  {e | branch.1 ∈ observation.dc.sigmaRel e}

/-- Stable environment identities shared by the entire lineage.  Loss-aware
branch tracking does not require a total map between branch carriers. -/
structure EnvironmentIdentity (E : Nat → Type u) where
  Medium : Type u
  identify : ∀ n, E n → Medium
  identify_injective : ∀ n, Function.Injective (identify n)

namespace EnvironmentIdentity

/-- Canonical identity for a lineage whose environment carrier is literally
shared by every generation. -/
def shared (E : Type u) : EnvironmentIdentity (fun _ ↦ E) where
  Medium := E
  identify := fun _ e ↦ e
  identify_injective := fun _ _ _ h ↦ h

end EnvironmentIdentity

/-- A lineage-level observation route.  Environment identity is fixed once for
the route, rather than chosen separately by each proliferation morphism. -/
structure BranchNoveltyRoute
    {generation : OpenEvolution.GenEvent.{u}}
    (lineage : OpenEvolution.Lineage generation) where
  observations : Nat → BranchObservation.{u}
  system_eq : ∀ n,
    Generation.dcToOpenSystem (observations n).dc = lineage.system n
  environmentIdentity :
    EnvironmentIdentity (fun n ↦ (observations n).E)

/-- Certified route boundary.  All generations literally share one environment
type and therefore use the canonical identity map.  The more general
`BranchNoveltyRoute` remains available as an explicitly trusted observation
boundary, but is not the route registered by the certificate catalog. -/
structure CanonicalBranchNoveltyRoute
    {generation : OpenEvolution.GenEvent.{u}}
    (lineage : OpenEvolution.Lineage generation) where
  E : Type u
  observations : Nat → SharedBranchObservation E
  system_eq : ∀ n,
    Generation.dcToOpenSystem (observations n).dc = lineage.system n

def CanonicalBranchNoveltyRoute.toBranchNoveltyRoute
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : CanonicalBranchNoveltyRoute lineage) :
    BranchNoveltyRoute lineage where
  observations := fun n ↦ (route.observations n).toBranchObservation
  system_eq := route.system_eq
  environmentIdentity := EnvironmentIdentity.shared route.E

/-- The structural image of one branching sigma-fibre in the lineage's fixed
medium. -/
def BranchImage
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage) (n : Nat)
    (branch : BranchCarrier (route.observations n)) :
    Set route.environmentIdentity.Medium :=
  route.environmentIdentity.identify n ''
    BranchFiber (route.observations n) branch

/-- Structural branch identity is equality of images in the fixed medium. -/
def StructuralImageIdentity
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage)
    {i j : Nat}
    (left : BranchCarrier (route.observations i))
    (right : BranchCarrier (route.observations j)) : Prop :=
  BranchImage route i left = BranchImage route j right

/-- All distinct structural branch images observed at one generation. -/
def GenerationBranchImages
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage) (n : Nat) :
    Set (Set route.environmentIdentity.Medium) :=
  {image | ∃ branch : BranchCarrier (route.observations n),
    BranchImage route n branch = image}

/-- A branch survives one step exactly when the next generation contains its
structural image.  This is derived data, not a caller-selected partial map. -/
def BranchSurvives
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage) (n : Nat)
    (branch : BranchCarrier (route.observations n)) : Prop :=
  BranchImage route n branch ∈ GenerationBranchImages route (n + 1)

/-- Loss is the absence of the old structural image at the next generation. -/
def BranchLost
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage) (n : Nat)
    (branch : BranchCarrier (route.observations n)) : Prop :=
  ¬ BranchSurvives route n branch

/-- Cumulative image history through generation `n`.  Images remain in history
after the corresponding capability is lost. -/
def BranchHistory
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage) (n : Nat) :
    Set (Set route.environmentIdentity.Medium) :=
  {image | ∃ k, k ≤ n ∧ image ∈ GenerationBranchImages route k}

/-- Arbitrarily late generations contain a branch image absent from the entire
strict prefix. -/
def BranchFresh
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage) : Prop :=
  ∀ cutoff, ∃ n, cutoff ≤ n ∧
    ∃ branch : BranchCarrier (route.observations n),
      ∀ k, k < n → ∀ old : BranchCarrier (route.observations k),
        BranchImage route n branch ≠ BranchImage route k old

/-- Semantic equivalence is admissible for the route only when it reflects the
complete set of structural branch images. -/
structure BranchReflectingSem
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage)
    (sem : OpenEvolution.SemanticEquivalence.{u}) : Prop where
  reflects : ∀ {i j}, sem.rel (lineage.system i) (lineage.system j) →
    GenerationBranchImages route i = GenerationBranchImages route j

/-- Direct bridge from loss-aware branch freshness to semantic freshness. -/
theorem branchFresh_implies_freshSem
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage)
    (sem : OpenEvolution.SemanticEquivalence.{u})
    (reflecting : BranchReflectingSem route sem)
    (fresh : BranchFresh route) :
    OpenEvolution.Lineage.FreshSem sem lineage := by
  intro cutoff
  obtain ⟨n, hcutoff, branch, hnovel⟩ := fresh cutoff
  refine ⟨n, hcutoff, ?_⟩
  intro k hk hsem
  have himages := reflecting.reflects hsem
  have hcurrent :
      BranchImage route n branch ∈ GenerationBranchImages route n :=
    ⟨branch, rfl⟩
  have hold : BranchImage route n branch ∈ GenerationBranchImages route k := by
    rw [← himages]
    exact hcurrent
  obtain ⟨old, hold⟩ := hold
  exact (hnovel k hk old) hold.symm

/-- Finiteness evidence for the executable cumulative score.  The numerical
score is derived and cannot be replaced by a caller-supplied quantity. -/
structure FiniteBranchScore
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    (route : BranchNoveltyRoute lineage) : Prop where
  history_finite : ∀ n, (BranchHistory route n).Finite

noncomputable def FiniteBranchScore.score
    {generation : OpenEvolution.GenEvent.{u}}
    {lineage : OpenEvolution.Lineage generation}
    {route : BranchNoveltyRoute lineage}
    (_finite : FiniteBranchScore route) (n : Nat) : Nat :=
  (BranchHistory route n).ncard

end BranchNovelty
end ERIEC
