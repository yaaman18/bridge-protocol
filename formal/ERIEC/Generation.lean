import ERIEC.DC
import ERIEC.Lineage
import ERIEC.Richness

namespace ERIEC
namespace Generation

universe u v

/-- Forget a certified DC unit to a local open system. The construction keeps
only the certified state as a local viable seed; it does not identify DC with
open-system viability and provides no inverse translation. -/
def dcToOpenSystem {M E C S : Type u} (dc : DC M E C S) :
    OpenEvolution.OpenSystem.{u} where
  Fast := S
  Slow := S
  Env := S
  step := fun _ => { (dc.s, (dc.s, dc.s)) }

/-- Viability predicate induced by the one-way DC-to-open-system adapter. -/
def dcViable {M E C S : Type u} (dc : DC M E C S) :
    OpenEvolution.Config (dcToOpenSystem dc) → Prop :=
  fun c => c.1 = dc.s

/-- One-way translation witness from a certified DC unit to a viable open
system. This is not a theorem in the reverse direction. -/
def dcViableTranslation {M E C S : Type u} (dc : DC M E C S) :
    OpenEvolution.ViableSystem.{u} where
  toOpenSystem := dcToOpenSystem dc
  viable := dcViable dc
  step_closed := by
    intro c c' _hc hstep
    rcases hstep with rfl
    rfl

/-- A local richness witness is a branch occurring on the certified hinge. -/
def RichnessWitness {M E C S : Type u} (dc : DC M E C S) : Prop :=
  ∃ m : M,
    m ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s ∧
      Richness.Branch dc.alphaRel m

/-- The finite structural quantity used for generational comparison. It is
zero for a branch-free DC unit and one when its active hinge has a branch. -/
noncomputable def phi_rich {M E C S : Type u} (dc : DC M E C S) : Nat :=
  by
    classical
    exact if RichnessWitness dc then 1 else 0

/-- A semantic-invariant richness quantity on the open-system side. This is
the fixed `q := Phi_rich` parameter for lineage openness, rather than an
arbitrary quantity supplied at each use site. -/
structure PhiRich (sem : OpenEvolution.SemanticEquivalence.{u}) where
  score : OpenEvolution.OpenSystem.{u} → Nat
  semantic_invariant : ∀ {left right}, sem.rel left right → score left = score right

/-- A meta-layer generation morphism between certified DC units.

It packages an ordinary `GenerationWitness` over the one-way DC-to-open-system
adapter, plus a local branch transport premise.  The premise is part of the
generation witness; it is not a new target-layer axiom and it does not provide
any inverse from viability back to DC. -/
structure ProliferationMorphism
    {M E C S M' E' C' S' : Type u}
    (parent : DC M E C S) (child : DC M' E' C' S') where
  Record : Type u
  Heritage : Type u
  parent_config : OpenEvolution.Config (dcToOpenSystem parent)
  child_config : OpenEvolution.Config (dcToOpenSystem child)
  record : Record
  parent_viable : dcViable parent parent_config
  child_viable : dcViable child child_config
  parentHeritage : OpenEvolution.Config (dcToOpenSystem parent) → Heritage
  childHeritage : OpenEvolution.Config (dcToOpenSystem child) → Heritage
  heritageRelated : Heritage → Heritage → Prop
  heritage_lax : heritageRelated (parentHeritage parent_config) (childHeritage child_config)
  Rank : Type u
  rank_preorder : Preorder Rank
  parent_rank : Rank
  child_rank : Rank
  wstar : Rank
  child_rank_le_wstar : rank_preorder.le child_rank wstar
  phi_rich_lax : phi_rich parent ≤ phi_rich child
  branch_transport :
    ∀ {m : M},
      m ∈ Hinge.Act parent.rhoRel parent.sigmaRel parent.kappa parent.epsilon parent.s →
      Richness.Branch parent.alphaRel m →
        ∃ m' : M',
          m' ∈ Hinge.Act child.rhoRel child.sigmaRel child.kappa child.epsilon child.s ∧
          Richness.Branch child.alphaRel m'

/-- Forget the proliferation-specific fields to the existing open-system
generation witness. -/
def ProliferationMorphism.toGenerationWitness
    {M E C S M' E' C' S' : Type u}
    {parent : DC M E C S} {child : DC M' E' C' S'}
    (f : ProliferationMorphism parent child) :
    OpenEvolution.GenerationWitness
      (dcToOpenSystem parent)
      (dcToOpenSystem child)
      f.Record
      f.Heritage
      (dcViable parent)
      (dcViable child)
      f.parentHeritage
      f.childHeritage
      f.heritageRelated where
  parent := f.parent_config
  child := f.child_config
  record := f.record
  parent_viable := f.parent_viable
  child_viable := f.child_viable
  heritage := f.heritage_lax

/-- The open-system event relation induced by one-way DC translations carrying
a proliferation witness. -/
def ProliferationEvent : OpenEvolution.GenEvent.{u} :=
  fun parentSystem childSystem =>
    ∃ (M E C S M' E' C' S' : Type u)
      (parent : DC M E C S) (child : DC M' E' C' S'),
        dcToOpenSystem parent = parentSystem ∧
        dcToOpenSystem child = childSystem ∧
        Nonempty (ProliferationMorphism parent child)

/-- Specialization of the open lineage theorem to proliferation events: if a
semantic-invariant structural quantity is cofinal along a proliferation
lineage, then the lineage stays semantically open. -/
theorem lineage_stays_open {Q : Type v} [PartialOrder Q]
    (sem : OpenEvolution.SemanticEquivalence.{u})
    (L : OpenEvolution.Lineage ProliferationEvent)
    (q : OpenEvolution.OpenSystem.{u} → Q)
    (q_invariant : ∀ {left right}, sem.rel left right → q left = q right)
    (hcofinal : OpenEvolution.Lineage.Cofinal q L) :
    OpenEvolution.Lineage.FreshSem sem L :=
  OpenEvolution.Lineage.cofinal_implies_freshSem sem L q q_invariant hcofinal

/-- The `Phi_rich` specialization of lineage openness. Its quantity and
semantic invariance are bundled once in `PhiRich`, so callers cannot silently
substitute an unrelated `q`. -/
theorem lineage_stays_open_phi_rich
    (sem : OpenEvolution.SemanticEquivalence.{u})
    (L : OpenEvolution.Lineage ProliferationEvent)
    (q : PhiRich sem)
    (hcofinal : OpenEvolution.Lineage.Cofinal q.score L) :
    OpenEvolution.Lineage.FreshSem sem L :=
  lineage_stays_open sem L q.score q.semantic_invariant hcofinal

/-- A proliferation witness transports a parent branch to a child branch; the
single-step richness pump then places the child branch inside the child's
coinductive hinge kernel. -/
theorem branch_transport_inherits_nu
    {M E C S M' E' C' S' : Type u}
    {parent : DC M E C S} {child : DC M' E' C' S'}
    (f : ProliferationMorphism parent child)
    {m : M}
    (hm : m ∈ Hinge.Act parent.rhoRel parent.sigmaRel parent.kappa parent.epsilon parent.s)
    (hbranch : Richness.Branch parent.alphaRel m) :
    ∃ m' : M',
      m' ∈ Hinge.Act child.rhoRel child.sigmaRel child.kappa child.epsilon child.s ∧
      Richness.Branch child.alphaRel m' ∧
      child.alphaRel m' ⊆ Closure.nu (Hinge.T_prime child.alphaRel child.sigmaRel) := by
  obtain ⟨m', hm', hbranch'⟩ := f.branch_transport hm hbranch
  exact ⟨m', hm', hbranch', Richness.hinge_branch_pump child m' hm' hbranch'⟩

/-- Generation-level richness is monotone by the witness-side `Phi_rich`
contract. The branch transport theorem remains available separately as
`branch_transport_inherits_nu`. -/
theorem richness_inherits_generational
    {M E C S M' E' C' S' : Type u}
    {parent : DC M E C S} {child : DC M' E' C' S'}
    (f : ProliferationMorphism parent child) :
    phi_rich parent ≤ phi_rich child :=
  f.phi_rich_lax

end Generation
end ERIEC
