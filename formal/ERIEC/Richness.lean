import ERIEC.DC

namespace ERIEC
namespace Richness

/-- A branch point is an action whose image contains two distinct environment
points. This is a classifier, not an additional object-layer axiom. -/
def Branch {M E : Type*} (alphaRel : M → Set E) (m : M) : Prop :=
  ∃ e₁ e₂ : E, e₁ ∈ alphaRel m ∧ e₂ ∈ alphaRel m ∧ e₁ ≠ e₂

theorem sigma_star_mono {M E : Type*} (sigmaRel : E → Set M) :
    Monotone (Adj.sigma_star sigmaRel) := by
  intro X Y hXY m hm
  rcases (by
    simpa [Adj.sigma_star] using hm : ∃ e, e ∈ X ∧ m ∈ sigmaRel e) with
    ⟨e, heX, hme⟩
  exact (by
    simp [Adj.sigma_star]
    exact ⟨e, hXY heX, hme⟩)

theorem alpha_star_mono {M E : Type*} (alphaRel : M → Set E) :
    Monotone (Adj.alpha_star alphaRel) := by
  intro X Y hXY e he
  rcases (by
    simpa [Adj.alpha_star] using he : ∃ m, m ∈ X ∧ e ∈ alphaRel m) with
    ⟨m, hmX, hem⟩
  exact (by
    simp [Adj.alpha_star]
    exact ⟨m, hXY hmX, hem⟩)

theorem T_prime_mono {M E : Type*} (alphaRel : M → Set E) (sigmaRel : E → Set M) :
    Monotone (Hinge.T_prime alphaRel sigmaRel) := by
  exact (alpha_star_mono alphaRel).comp (sigma_star_mono sigmaRel)

theorem alpha_subset_T_prime_of_act {M E C S : Type*}
    (dc : DC M E C S)
    {m : M}
    (hm : m ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s) :
    dc.alphaRel m ⊆ Hinge.T_prime dc.alphaRel dc.sigmaRel (dc.epsilon dc.s) := by
  intro e he
  exact (by
    simp [Hinge.T_prime, Adj.alpha_star]
    exact ⟨m, hm.2, he⟩)

def HingeBranchPump {M E C S : Type*} (dc : DC M E C S) : Prop :=
  ∀ m ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s,
    Branch dc.alphaRel m →
      dc.alphaRel m ⊆ Closure.nu (Hinge.T_prime dc.alphaRel dc.sigmaRel)

def HingeBranchPumpWidth {M E C S : Type*} (dc : DC M E C S) : Prop :=
  ∀ m ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s,
    Branch dc.alphaRel m →
      ∃ e₁ e₂ : E,
        e₁ ∈ Closure.nu (Hinge.T_prime dc.alphaRel dc.sigmaRel) ∧
        e₂ ∈ Closure.nu (Hinge.T_prime dc.alphaRel dc.sigmaRel) ∧ e₁ ≠ e₂

theorem hinge_branch_pump {M E C S : Type*} (dc : DC M E C S) :
    HingeBranchPump dc := by
  intro m hm _hbranch e he
  let Y : Set E := dc.epsilon dc.s ∪ dc.alphaRel m
  have heY : e ∈ Y := Or.inr he
  have h_eps_subset : dc.epsilon dc.s ⊆ Y := by
    intro x hx
    exact Or.inl hx
  have h_alpha_subset :
      dc.alphaRel m ⊆ Hinge.T_prime dc.alphaRel dc.sigmaRel (dc.epsilon dc.s) :=
    alpha_subset_T_prime_of_act dc hm
  have hT_mono : Monotone (Hinge.T_prime dc.alphaRel dc.sigmaRel) :=
    T_prime_mono dc.alphaRel dc.sigmaRel
  have hpost : Y ⊆ Hinge.T_prime dc.alphaRel dc.sigmaRel Y := by
    intro x hx
    rcases hx with hx | hx
    · exact hT_mono h_eps_subset (dc.hSMC hx)
    · exact hT_mono h_eps_subset (h_alpha_subset hx)
  exact Closure.coinduction hpost heY

theorem hinge_branch_pump_width {M E C S : Type*} (dc : DC M E C S) :
    HingeBranchPumpWidth dc := by
  intro m hm hbranch
  rcases hbranch with ⟨e₁, e₂, he₁, he₂, hne⟩
  exact ⟨e₁, e₂, hinge_branch_pump dc m hm ⟨e₁, e₂, he₁, he₂, hne⟩ he₁,
    hinge_branch_pump dc m hm ⟨e₁, e₂, he₁, he₂, hne⟩ he₂, hne⟩

end Richness
end ERIEC
