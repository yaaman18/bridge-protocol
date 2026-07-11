import Mathlib.Order.GaloisConnection.Basic

namespace ERIEC

namespace Adj

def alpha_star {M E : Type*} (alphaRel : M -> Set E) (N : Set M) : Set E :=
  ⋃ m ∈ N, alphaRel m

def sigma_star_induced {M E : Type*} (alphaRel : M -> Set E) (X : Set E) : Set M :=
  {m | alphaRel m ⊆ X}

theorem galoisConn_induced {M E : Type*} (alphaRel : M -> Set E) :
    GaloisConnection (alpha_star alphaRel) (sigma_star_induced alphaRel) := by
  intro N X
  constructor
  · intro h m hm e he
    exact h (by
      simp [alpha_star]
      exact ⟨m, hm, he⟩)
  · intro h e he
    rcases (by
      simpa [alpha_star] using he : ∃ m, m ∈ N ∧ e ∈ alphaRel m) with
      ⟨m, hm, heRel⟩
    exact h hm heRel

theorem unit_induced {M E : Type*} (alphaRel : M -> Set E) (N : Set M) :
    N ⊆ sigma_star_induced alphaRel (alpha_star alphaRel N) :=
  (galoisConn_induced alphaRel).le_u_l N

theorem counit_induced {M E : Type*} (alphaRel : M -> Set E) (X : Set E) :
    alpha_star alphaRel (sigma_star_induced alphaRel X) ⊆ X :=
  (galoisConn_induced alphaRel).l_u_le X

def sigma_star {M E : Type*} (sigmaRel : E -> Set M) (X : Set E) : Set M :=
  ⋃ e ∈ X, sigmaRel e

structure ERIESystem (M E : Type*) where
  alphaRel : M -> Set E
  sigmaRel : E -> Set M
  hGC : GaloisConnection (alpha_star alphaRel) (sigma_star sigmaRel)

theorem unit_of_gc {M E : Type*} (sys : ERIESystem M E) (N : Set M) :
    N ⊆ sigma_star sys.sigmaRel (alpha_star sys.alphaRel N) :=
  sys.hGC.le_u_l N

theorem counit_of_gc {M E : Type*} (sys : ERIESystem M E) (X : Set E) :
    alpha_star sys.alphaRel (sigma_star sys.sigmaRel X) ⊆ X :=
  sys.hGC.l_u_le X

/-- A relation whose existential direct image is right adjoint is forced to be
single-valued, and the right-hand relation is its converse. -/
theorem rigidity_of_gc {M E : Type*}
    (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (hGC : GaloisConnection (alpha_star alphaRel) (sigma_star sigmaRel)) :
    (∀ m, ∃! e, e ∈ alphaRel m) ∧
      (∀ m e, m ∈ sigmaRel e ↔ e ∈ alphaRel m) := by
  have witness : ∀ m, ∃ e, e ∈ alphaRel m ∧ m ∈ sigmaRel e := by
    intro m
    have hunit : m ∈ sigma_star sigmaRel (alpha_star alphaRel {m}) :=
      hGC.le_u_l {m} (by simp)
    simpa [alpha_star, sigma_star] using hunit
  have atMostOne : ∀ m {left right}, left ∈ alphaRel m → right ∈ alphaRel m → left = right := by
    intro m left right hleft hright
    obtain ⟨w, hwAlpha, hwSigma⟩ := witness m
    have hcounit := hGC.l_u_le ({w} : Set E)
    have member_of_singleton : ∀ {e}, e ∈ alphaRel m → e ∈ ({w} : Set E) := by
      intro e he
      apply hcounit
      simp only [alpha_star, sigma_star, Set.mem_iUnion, Set.mem_singleton_iff]
      exact ⟨m, ⟨w, rfl, hwSigma⟩, he⟩
    exact (Set.mem_singleton_iff.mp (member_of_singleton hleft)).trans
      (Set.mem_singleton_iff.mp (member_of_singleton hright)).symm
  constructor
  · intro m
    obtain ⟨e, heAlpha, heSigma⟩ := witness m
    refine ⟨e, heAlpha, ?_⟩
    intro other hother
    exact atMostOne m hother heAlpha
  · intro m e
    constructor
    · intro hm
      obtain ⟨w, hwAlpha, _⟩ := witness m
      have hcounit := hGC.l_u_le ({e} : Set E)
      have hmem : w ∈ alpha_star alphaRel (sigma_star sigmaRel {e}) := by
        simp only [alpha_star, sigma_star, Set.mem_iUnion, Set.mem_singleton_iff]
        exact ⟨m, ⟨e, rfl, hm⟩, hwAlpha⟩
      exact Set.mem_singleton_iff.mp (hcounit hmem) ▸ hwAlpha
    · intro he
      obtain ⟨w, hwAlpha, hwSigma⟩ := witness m
      exact atMostOne m hwAlpha he ▸ hwSigma

/-- Dual-consistent data keeps the existential sensory relation separate from
the universal right adjoint induced by the action relation. -/
structure ConvSystem (M E : Type*) where
  alphaRel : M → Set E
  sigmaRel : E → Set M
  hConv : ∀ m e, e ∈ alphaRel m ↔ m ∈ sigmaRel e

def sigma_forall {M E : Type*} (sigmaRel : E → Set M) (X : Set E) : Set M :=
  {m | ∀ e, m ∈ sigmaRel e → e ∈ X}

theorem sigma_forall_eq_induced {M E : Type*} (sys : ConvSystem M E) :
    sigma_forall sys.sigmaRel = sigma_star_induced sys.alphaRel := by
  funext X
  ext m
  constructor
  · intro h e he
    exact h e ((sys.hConv m e).mp he)
  · intro h e he
    exact h ((sys.hConv m e).mpr he)

theorem conv_gc {M E : Type*} (sys : ConvSystem M E) :
    GaloisConnection (alpha_star sys.alphaRel) (sigma_forall sys.sigmaRel) := by
  rw [sigma_forall_eq_induced sys]
  exact galoisConn_induced sys.alphaRel

end Adj

end ERIEC
