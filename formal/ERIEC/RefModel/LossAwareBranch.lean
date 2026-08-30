import ERIEC.BranchNovelty
import ERIEC.RefModel.LineageWitness

namespace ERIEC
namespace RefModel

open OpenEvolution

/-- The generation-`n` branch image in the loss-aware positive reference
family.  The environment carrier is shared while the observed fibre grows. -/
def noveltyBranchFiber (n : Nat) : Set Nat :=
  {e | e ≤ n + 1}

/-- A converse-consistent DC family with a shared environment carrier and a
genuinely new sigma-fibre at every generation. -/
def noveltyPositiveDC (n : Nat) : DC Unit Nat Unit (Fin (n + 1)) where
  alphaRel := fun _ ↦ noveltyBranchFiber n
  sigmaRel := fun e ↦ {m | e ∈ noveltyBranchFiber n}
  piRel := fun _ ↦ Set.univ
  rhoRel := fun _ ↦ Set.univ
  kappa := fun _ ↦ Set.univ
  epsilon := fun _ ↦ noveltyBranchFiber n
  boundary := Set.univ
  s := 0
  hSelf := by
    intro c _
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star]
  hSMC := by
    intro e he
    simp only [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, Set.mem_iUnion]
    exact ⟨(), ⟨0, Nat.zero_le _, Nat.zero_le _⟩, he⟩
  hAct := by
    refine ⟨(), ?_⟩
    constructor
    · simp [Closure.rho_star]
    · simp only [Adj.sigma_star, Set.mem_iUnion]
      exact ⟨0, Nat.zero_le _, Nat.zero_le _⟩
  hBound := by simp

theorem noveltyPositiveDC_hConv (n : Nat) :
    ∀ m e,
      e ∈ (noveltyPositiveDC n).alphaRel m ↔
        m ∈ (noveltyPositiveDC n).sigmaRel e := by
  intro m e
  rfl

def noveltyPositiveObservation (n : Nat) : BranchNovelty.BranchObservation where
  M := Unit
  E := Nat
  C := Unit
  S := Fin (n + 1)
  dc := noveltyPositiveDC n
  hConv := noveltyPositiveDC_hConv n

theorem noveltyPositiveDC_branch (n : Nat) :
    Richness.Branch (noveltyPositiveDC n).alphaRel () := by
  refine ⟨0, 1, ?_, ?_, by decide⟩
  · exact Nat.zero_le _
  · exact Nat.succ_le_succ (Nat.zero_le n)

theorem noveltyPositiveDC_richnessWitness (n : Nat) :
    Generation.RichnessWitness (noveltyPositiveDC n) := by
  rcases (noveltyPositiveDC n).hAct with ⟨m, hm⟩
  cases m
  exact ⟨(), hm, noveltyPositiveDC_branch n⟩

theorem noveltyPositiveDC_phi_rich_eq_one (n : Nat) :
    Generation.phi_rich (noveltyPositiveDC n) = 1 := by
  simp [Generation.phi_rich, noveltyPositiveDC_richnessWitness]

/-- Adjacent positive generations remain ordinary proliferation events.  The
legacy branch witness is retained, but novelty and loss are derived separately
by `BranchNoveltyRoute`. -/
def noveltyPositiveStep (n : Nat) :
    Generation.ProliferationMorphism
      (noveltyPositiveDC n) (noveltyPositiveDC (n + 1)) where
  Record := Unit
  Heritage := Unit
  parent_config :=
    ((noveltyPositiveDC n).s,
      ((noveltyPositiveDC n).s, (noveltyPositiveDC n).s))
  child_config :=
    ((noveltyPositiveDC (n + 1)).s,
      ((noveltyPositiveDC (n + 1)).s, (noveltyPositiveDC (n + 1)).s))
  record := ()
  parent_viable := rfl
  child_viable := rfl
  parentHeritage := fun _ ↦ ()
  childHeritage := fun _ ↦ ()
  heritageRelated := fun _ _ ↦ True
  heritage_lax := trivial
  Rank := Unit
  rank_preorder := inferInstance
  parent_rank := ()
  child_rank := ()
  wstar := ()
  child_rank_le_wstar := le_rfl
  phi_rich_lax := by
    rw [noveltyPositiveDC_phi_rich_eq_one,
      noveltyPositiveDC_phi_rich_eq_one]
  branch_transport := by
    intro _m _hm _hbranch
    rcases (noveltyPositiveDC (n + 1)).hAct with ⟨m, hm⟩
    cases m
    exact ⟨(), hm, noveltyPositiveDC_branch (n + 1)⟩

def noveltyPositiveLineage : Lineage Generation.ProliferationEvent where
  system := fun n ↦ Generation.dcToOpenSystem (noveltyPositiveDC n)
  event := by
    intro n
    exact ⟨Unit, Nat, Unit, Fin (n + 1),
      Unit, Nat, Unit, Fin (n + 1 + 1),
      noveltyPositiveDC n, noveltyPositiveDC (n + 1), rfl, rfl,
      ⟨noveltyPositiveStep n⟩⟩

def noveltyPositiveRoute :
    BranchNovelty.BranchNoveltyRoute noveltyPositiveLineage where
  observations := noveltyPositiveObservation
  system_eq := fun _ ↦ rfl
  environmentIdentity := BranchNovelty.EnvironmentIdentity.shared Nat

def noveltyPositiveBranch (n : Nat) :
    BranchNovelty.BranchCarrier (noveltyPositiveObservation n) :=
  ⟨(), (BranchNovelty.branchSigma_iff_branch
    (noveltyPositiveDC_hConv n) ()).mpr (noveltyPositiveDC_branch n)⟩

theorem noveltyPositive_branchImage (n : Nat)
    (branch : BranchNovelty.BranchCarrier (noveltyPositiveObservation n)) :
    BranchNovelty.BranchImage noveltyPositiveRoute n branch =
      noveltyBranchFiber n := by
  unfold BranchNovelty.BranchImage
  dsimp [noveltyPositiveRoute, BranchNovelty.EnvironmentIdentity.shared]
  ext e
  simp [BranchNovelty.BranchFiber, noveltyPositiveObservation, noveltyPositiveDC,
    noveltyBranchFiber]
  change e ≤ n + 1 ↔ e ≤ n + 1
  rfl

theorem noveltyPositive_branchFresh :
    BranchNovelty.BranchFresh noveltyPositiveRoute := by
  intro cutoff
  refine ⟨cutoff, le_rfl, noveltyPositiveBranch cutoff, ?_⟩
  intro k hk old heq
  have himages : noveltyBranchFiber cutoff = noveltyBranchFiber k := by
    rw [noveltyPositive_branchImage, noveltyPositive_branchImage] at heq
    exact heq
  have hcurrent : cutoff + 1 ∈ noveltyBranchFiber cutoff := by
    simp [noveltyBranchFiber]
  have hold : cutoff + 1 ∈ noveltyBranchFiber k :=
    (Set.ext_iff.mp himages (cutoff + 1)).mp hcurrent
  simp [noveltyBranchFiber] at hold
  omega

/-- The old exact branch image is lost at every step even though the next
generation has a richer replacement.  Loss therefore remains inside the
certified route rather than being excluded by a total carry premise. -/
theorem noveltyPositive_branchLost (n : Nat) :
    BranchNovelty.BranchLost noveltyPositiveRoute n
      (noveltyPositiveBranch n) := by
  intro hsurvives
  obtain ⟨child, hchild⟩ := hsurvives
  have himages : noveltyBranchFiber (n + 1) = noveltyBranchFiber n := by
    rw [noveltyPositive_branchImage, noveltyPositive_branchImage] at hchild
    exact hchild
  have hcurrent : n + 2 ∈ noveltyBranchFiber (n + 1) := by
    simp [noveltyBranchFiber]
  have hold : n + 2 ∈ noveltyBranchFiber n :=
    (Set.ext_iff.mp himages (n + 2)).mp hcurrent
  simp [noveltyBranchFiber] at hold

theorem noveltyPositive_branchReflecting :
    BranchNovelty.BranchReflectingSem noveltyPositiveRoute cardSem := by
  constructor
  intro i j hsem
  rcases hsem with ⟨e⟩
  have hcard := Nat.card_congr e
  have hij : i = j := by
    simpa [noveltyPositiveLineage, Generation.dcToOpenSystem] using hcard
  subst j
  rfl

theorem noveltyPositive_freshSem :
    Lineage.FreshSem cardSem noveltyPositiveLineage :=
  BranchNovelty.branchFresh_implies_freshSem
    noveltyPositiveRoute cardSem noveltyPositive_branchReflecting
    noveltyPositive_branchFresh

end RefModel
end ERIEC
