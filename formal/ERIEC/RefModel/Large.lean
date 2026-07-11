import ERIEC.RefModel.Richness

namespace ERIEC
namespace RefModel

def finFullRelation {k : ℕ} (_ : Fin k) : Set (Fin k) := Set.univ

/-- A finite DC with all three carriers of size `k`. -/
def largeFiniteDC (k : ℕ) (hk : 0 < k) : DC (Fin k) (Fin k) (Fin k) Unit where
  alphaRel := finFullRelation
  sigmaRel := finFullRelation
  piRel := finFullRelation
  rhoRel := finFullRelation
  kappa := fun _ => Set.univ
  epsilon := fun _ => Set.univ
  boundary := Set.univ
  s := ()
  hSelf := by
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    intro c _
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star, finFullRelation]
  hSMC := by
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    intro e _
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, finFullRelation]
  hAct := by
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    let a : Fin k := ⟨0, hk⟩
    exact ⟨a, by simp [Hinge.Act, Closure.rho_star, Adj.sigma_star,
      finFullRelation]⟩
  hBound := by
    let c : Fin k := ⟨0, hk⟩
    exact ⟨c, by simp⟩

structure LargeNondegenerateWitness (k : ℕ) : Type where
  dc : DC (Fin k) (Fin k) (Fin k) Unit
  action_card : Fintype.card (Fin k) = k
  environment_card : Fintype.card (Fin k) = k
  core_card : Fintype.card (Fin k) = k
  multivalued : ∃ a e1 e2 : Fin k,
    e1 ≠ e2 ∧ e1 ∈ dc.alphaRel a ∧ e2 ∈ dc.alphaRel a
  hinge_nonempty :
    (Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty

/-- Finite arbitrary-size part of M-1: for every `k ≥ 2`, all carriers can
have size `k`, while the sensory relation is genuinely multivalued. -/
theorem arbitrarily_large_nondegenerate_dc (k : ℕ) (hk : 2 ≤ k) :
    Nonempty (LargeNondegenerateWitness k) := by
  let a : Fin k := ⟨0, lt_of_lt_of_le (by decide) hk⟩
  let e1 : Fin k := ⟨0, lt_of_lt_of_le (by decide) hk⟩
  let e2 : Fin k := ⟨1, hk⟩
  let dc := largeFiniteDC k (lt_of_lt_of_le (by decide) hk)
  refine ⟨{
    dc := dc
    action_card := by simp
    environment_card := by simp
    core_card := by simp
    multivalued := ⟨a, e1, e2, ?_, ?_, ?_⟩
    hinge_nonempty := dc.hAct
  }⟩
  · simp [e1, e2]
  · simp [dc, largeFiniteDC, finFullRelation]
  · simp [dc, largeFiniteDC, finFullRelation]

end RefModel
end ERIEC
