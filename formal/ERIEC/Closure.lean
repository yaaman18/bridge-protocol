import ERIEC.Adjunction

namespace ERIEC

namespace Closure

def pi_star {M C : Type*} (piRel : M -> Set C) (A : Set M) : Set C :=
  ⋃ m ∈ A, piRel m

def rho_star {M C : Type*} (rhoRel : C -> Set M) (Y : Set C) : Set M :=
  ⋃ c ∈ Y, rhoRel c

def Phi {M C : Type*} (piRel : M -> Set C) (rhoRel : C -> Set M)
    (Y : Set C) : Set C :=
  pi_star piRel (rho_star rhoRel Y)

theorem pi_star_mono {M C : Type*} (piRel : M -> Set C) :
    Monotone (pi_star piRel) := by
  intro A B hAB c hc
  rcases (by
    simpa [pi_star] using hc : ∃ m, m ∈ A ∧ c ∈ piRel m) with
    ⟨m, hm, hcm⟩
  exact (by
    simp [pi_star]
    exact ⟨m, hAB hm, hcm⟩)

theorem rho_star_mono {M C : Type*} (rhoRel : C -> Set M) :
    Monotone (rho_star rhoRel) := by
  intro Y Z hYZ m hm
  rcases (by
    simpa [rho_star] using hm : ∃ c, c ∈ Y ∧ m ∈ rhoRel c) with
    ⟨c, hc, hmc⟩
  exact (by
    simp [rho_star]
    exact ⟨c, hYZ hc, hmc⟩)

theorem phi_mono {M C : Type*} (piRel : M -> Set C) (rhoRel : C -> Set M) :
    Monotone (Phi piRel rhoRel) := by
  exact (pi_star_mono piRel).comp (rho_star_mono rhoRel)

structure NuPhi (M C : Type*) where
  piRel : M -> Set C
  rhoRel : C -> Set M
  nuPhi : Set C
  isFixedPoint : Phi piRel rhoRel nuPhi = nuPhi
  isGreatest : ∀ Y : Set C, Phi piRel rhoRel Y = Y -> Y ⊆ nuPhi

theorem nuPhi_isFixedPoint {M C : Type*} (np : NuPhi M C) :
    Phi np.piRel np.rhoRel np.nuPhi = np.nuPhi :=
  np.isFixedPoint

theorem nuPhi_isGreatest {M C : Type*} (np : NuPhi M C) (Y : Set C)
    (hY : Phi np.piRel np.rhoRel Y = Y) :
    Y ⊆ np.nuPhi :=
  np.isGreatest Y hY

/-- Knaster--Tarski greatest post-fixed point, defined without iteration. -/
def nu {C : Type*} (F : Set C → Set C) : Set C :=
  ⋃₀ {Y : Set C | Y ⊆ F Y}

theorem coinduction {C : Type*} {F : Set C → Set C} {Y : Set C}
    (hY : Y ⊆ F Y) : Y ⊆ nu F := by
  intro c hc
  exact Set.mem_sUnion.mpr ⟨Y, hY, hc⟩

theorem nu_postfixed {C : Type*} {F : Set C → Set C} (hmono : Monotone F) :
    nu F ⊆ F (nu F) := by
  intro c hc
  obtain ⟨Y, hY, hcY⟩ := Set.mem_sUnion.mp hc
  exact hmono (coinduction hY) (hY hcY)

theorem nu_prefixed {C : Type*} {F : Set C → Set C} (hmono : Monotone F) :
    F (nu F) ⊆ nu F := by
  apply coinduction
  exact hmono (nu_postfixed hmono)

theorem nu_fixed {C : Type*} {F : Set C → Set C} (hmono : Monotone F) :
    F (nu F) = nu F :=
  Set.Subset.antisymm (nu_prefixed hmono) (nu_postfixed hmono)

/-- `nu F` is final in the thin category of post-fixed points. -/
theorem finalCoalgebra {C : Type*} {F : Set C → Set C} (_hmono : Monotone F)
    (Y : Set C) (hY : Y ⊆ F Y) :
    Y ⊆ nu F :=
  coinduction hY

end Closure

end ERIEC
