import Mathlib.Data.Set.Card
import ERIEC.Generation
import ERIEC.RefModel.Richness

namespace ERIEC
namespace RefModel

open OpenEvolution

/-- A finite DC family whose state type and active-hinge cardinality both
grow with the generation index.  This is a concrete reference family, not a
new target-layer assumption. -/
def richLineageDC (n : ℕ) : DC (Fin (n + 1)) Unit Unit (Fin (n + 1)) where
  alphaRel := finFullRel
  sigmaRel := unitFinFullRel
  piRel := finFullRel
  rhoRel := unitFinFullRel
  kappa := fun _ => Set.univ
  epsilon := fun _ => Set.univ
  boundary := Set.univ
  s := 0
  hSelf := by
    intro c _
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star, finFullRel,
      unitFinFullRel]
  hSMC := by
    intro e _
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, finFullRel,
      unitFinFullRel]
  hAct := by
    exact ⟨0, by simp [Hinge.Act, Closure.rho_star, Adj.sigma_star,
      unitFinFullRel]⟩
  hBound := by simp

theorem richLineageDC_act_eq_univ (n : ℕ) :
    Hinge.Act (richLineageDC n).rhoRel
      (richLineageDC n).sigmaRel
      (richLineageDC n).kappa
      (richLineageDC n).epsilon
      (richLineageDC n).s = Set.univ := by
  ext m
  simp [richLineageDC, Hinge.Act, Closure.rho_star, Adj.sigma_star,
    unitFinFullRel]

theorem richLineageDC_not_richnessWitness (n : ℕ) :
    ¬ Generation.RichnessWitness (richLineageDC n) := by
  rintro ⟨m, _hm, e₁, e₂, _he₁, _he₂, hne⟩
  exact hne (Subsingleton.elim e₁ e₂)

theorem richLineageDC_phi_rich_eq_zero (n : ℕ) :
    Generation.phi_rich (richLineageDC n) = 0 := by
  simp [Generation.phi_rich, richLineageDC_not_richnessWitness]

/-- The concrete proliferation witness between adjacent members of the rich
lineage family.  Since the environment type is `Unit`, branch transport is
vacuous; cofinality below is carried by the independent semantic score. -/
def richLineageStep (n : ℕ) :
    Generation.ProliferationMorphism (richLineageDC n) (richLineageDC (n + 1)) where
  Record := Unit
  Heritage := Unit
  parent_config :=
    ((richLineageDC n).s, ((richLineageDC n).s, (richLineageDC n).s))
  child_config :=
    ((richLineageDC (n + 1)).s,
      ((richLineageDC (n + 1)).s, (richLineageDC (n + 1)).s))
  record := ()
  parent_viable := rfl
  child_viable := rfl
  parentHeritage := fun _ => ()
  childHeritage := fun _ => ()
  heritageRelated := fun _ _ => True
  heritage_lax := trivial
  Rank := Unit
  rank_preorder := inferInstance
  parent_rank := ()
  child_rank := ()
  wstar := ()
  child_rank_le_wstar := le_rfl
  phi_rich_lax := by
    rw [richLineageDC_phi_rich_eq_zero, richLineageDC_phi_rich_eq_zero]
  branch_transport := by
    intro m _hm hbranch
    rcases hbranch with ⟨e₁, e₂, _he₁, _he₂, hne⟩
    exact False.elim (hne (Subsingleton.elim e₁ e₂))

/-- Semantic equivalence by equipotence of the fast-state types. -/
def cardSem : SemanticEquivalence where
  rel := fun left right => Nonempty (left.Fast ≃ right.Fast)
  refl := fun _ => ⟨Equiv.refl _⟩
  symm := by
    rintro _ _ ⟨e⟩
    exact ⟨e.symm⟩
  trans := by
    rintro _ _ _ ⟨e₁⟩ ⟨e₂⟩
    exact ⟨e₁.trans e₂⟩

/-- Read-only semantic score used to witness cofinality. -/
noncomputable def cardPhiRich : Generation.PhiRich cardSem where
  score := fun system => Nat.card system.Fast
  semantic_invariant := by
    rintro left right ⟨e⟩
    exact Nat.card_congr e

/-- The concrete lineage of adjacent finite rich reference systems. -/
def richLineage : Lineage Generation.ProliferationEvent where
  system := fun n => Generation.dcToOpenSystem (richLineageDC n)
  event := by
    intro n
    exact ⟨Fin (n + 1), Unit, Unit, Fin (n + 1),
      Fin (n + 1 + 1), Unit, Unit, Fin (n + 1 + 1),
      richLineageDC n, richLineageDC (n + 1), rfl, rfl,
      ⟨richLineageStep n⟩⟩

theorem cardPhiRich_score_richLineage (n : ℕ) :
    cardPhiRich.score (richLineage.system n) = n + 1 := by
  simp [cardPhiRich, richLineage, Generation.dcToOpenSystem]

theorem richLineage_score_eq_hinge_card (n : ℕ) :
    cardPhiRich.score (richLineage.system n) =
      (Hinge.Act (richLineageDC n).rhoRel
        (richLineageDC n).sigmaRel
        (richLineageDC n).kappa
        (richLineageDC n).epsilon
        (richLineageDC n).s).ncard := by
  rw [cardPhiRich_score_richLineage, richLineageDC_act_eq_univ]
  simp

theorem richLineage_cofinal :
    Lineage.Cofinal cardPhiRich.score richLineage := by
  intro bound
  exact ⟨bound, by simp [cardPhiRich_score_richLineage]⟩

/-- A concrete witness that the proliferation event admits a lineage with an
unbounded semantic-invariant richness proxy. -/
structure RichLineageWitness : Type 1 where
  lineage : Lineage Generation.ProliferationEvent
  system_eq : ∀ n, lineage.system n =
    Generation.dcToOpenSystem (richLineageDC n)
  score_eq_hinge_card : ∀ n,
    cardPhiRich.score (lineage.system n) =
      (Hinge.Act (richLineageDC n).rhoRel
        (richLineageDC n).sigmaRel
        (richLineageDC n).kappa
        (richLineageDC n).epsilon
        (richLineageDC n).s).ncard
  cofinal : Lineage.Cofinal cardPhiRich.score lineage

/-- VP-GEN-005: the concrete cofinal rich-lineage witness exists. -/
theorem rich_lineage_reference_model : Nonempty RichLineageWitness := by
  exact ⟨{
    lineage := richLineage
    system_eq := fun _ => rfl
    score_eq_hinge_card := richLineage_score_eq_hinge_card
    cofinal := richLineage_cofinal
  }⟩

theorem rich_lineage_freshSem (w : RichLineageWitness) :
    Lineage.FreshSem cardSem w.lineage :=
  Generation.lineage_stays_open_phi_rich cardSem w.lineage cardPhiRich w.cofinal

theorem rich_lineage_not_eventuallyPeriodic (w : RichLineageWitness) :
    ¬ Lineage.EventuallyPeriodicSem cardSem w.lineage :=
  Lineage.freshSem_not_eventuallyPeriodicSem cardSem w.lineage
    (rich_lineage_freshSem w)

end RefModel
end ERIEC
