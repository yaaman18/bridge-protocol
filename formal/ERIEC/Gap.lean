import ERIEC.Adjunction
import ERIEC.Richness

namespace ERIEC
namespace Gap

/-- The E-side universal lift dual to `Adj.sigma_star`. -/
def alpha_forall {M E : Type*} (sigmaRel : E → Set M) (N : Set M) : Set E :=
  {e | sigmaRel e ⊆ N}

theorem second_gc {M E : Type*} (sigmaRel : E → Set M) :
    GaloisConnection (Adj.sigma_star sigmaRel) (alpha_forall sigmaRel) := by
  intro X N
  constructor
  · intro h e he m hm
    exact h (by
      simp [Adj.sigma_star]
      exact ⟨e, he, hm⟩)
  · intro h m hm
    rcases (by
      simpa [Adj.sigma_star] using hm : ∃ e, e ∈ X ∧ m ∈ sigmaRel e) with
      ⟨e, heX, hme⟩
    exact h heX hme

/-- Upward gap: existential sensory reach sees `a`, but the universal lift
does not certify the whole action image. -/
def GapUp {M E : Type*} (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (a : M) : Prop :=
  ∃ X : Set E,
    a ∈ Adj.sigma_star sigmaRel X ∧
    a ∉ Adj.sigma_star_induced alphaRel X

/-- Downward gap: universal lift certifies an empty action image while
existential sensory reach sees nothing. -/
def GapDn {M E : Type*} (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (a : M) : Prop :=
  ∃ X : Set E,
    a ∈ Adj.sigma_star_induced alphaRel X ∧
    a ∉ Adj.sigma_star sigmaRel X

/-- Degenerate points are exactly single-valued action images. -/
def SingletonImage {M E : Type*} (alphaRel : M → Set E) (a : M) : Prop :=
  ∃ e, alphaRel a = {e}

theorem alpha_forall_eq_of_conv {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) :
    alpha_forall sigmaRel = fun N : Set M => {e | ∀ a, e ∈ alphaRel a → a ∈ N} := by
  funext N
  ext e
  constructor
  · intro h a hea
    exact h ((hConv a e).mp hea)
  · intro h a hae
    exact h a ((hConv a e).mpr hae)

theorem gapUp_iff_branch {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) (a : M) :
    GapUp alphaRel sigmaRel a ↔ Richness.Branch alphaRel a := by
  constructor
  · rintro ⟨X, hsig, hnot⟩
    rcases (by
      simpa [Adj.sigma_star] using hsig : ∃ e, e ∈ X ∧ a ∈ sigmaRel e) with
      ⟨e₁, he₁X, haσ⟩
    have he₁α : e₁ ∈ alphaRel a := (hConv a e₁).mpr haσ
    have hnsubset : ¬ alphaRel a ⊆ X := by
      simpa [Adj.sigma_star_induced] using hnot
    rcases Set.not_subset.mp hnsubset with ⟨e₂, he₂α, he₂notX⟩
    exact ⟨e₁, e₂, he₁α, he₂α, fun h => he₂notX (h ▸ he₁X)⟩
  · rintro ⟨e₁, e₂, he₁α, he₂α, hne⟩
    refine ⟨({e₁} : Set E), ?_, ?_⟩
    · simp [Adj.sigma_star, (hConv a e₁).mp he₁α]
    · simp [Adj.sigma_star_induced]
      exact ⟨e₂, he₂α, hne.symm⟩

theorem gapDn_iff_empty {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) (a : M) :
    GapDn alphaRel sigmaRel a ↔ alphaRel a = ∅ := by
  constructor
  · rintro ⟨X, hinduced, hnotSig⟩
    ext e
    constructor
    · intro heα
      have heX : e ∈ X := by
        simpa [Adj.sigma_star_induced] using hinduced heα
      have haσ : a ∈ sigmaRel e := (hConv a e).mp heα
      exact False.elim (hnotSig (by
        simp [Adj.sigma_star]
        exact ⟨e, heX, haσ⟩))
    · intro h
      exact False.elim (by simpa using h)
  · intro hempty
    refine ⟨(∅ : Set E), ?_, ?_⟩
    · simp [Adj.sigma_star_induced, hempty]
    · simp [Adj.sigma_star]

theorem sigma_star_eq_induced_iff_singleton {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) :
    Adj.sigma_star sigmaRel = Adj.sigma_star_induced alphaRel ↔
      ∀ a, SingletonImage alphaRel a := by
  constructor
  · intro hEq a
    have hnonempty : (alphaRel a).Nonempty := by
      by_contra hempty
      have haInduced : a ∈ Adj.sigma_star_induced alphaRel (∅ : Set E) := by
        intro e he
        exact False.elim (hempty ⟨e, he⟩)
      have haSig : a ∈ Adj.sigma_star sigmaRel (∅ : Set E) := by
        simpa [hEq] using haInduced
      simpa [Adj.sigma_star] using haSig
    rcases hnonempty with ⟨e, heα⟩
    have haSigSingleton : a ∈ Adj.sigma_star sigmaRel ({e} : Set E) := by
      simp [Adj.sigma_star, (hConv a e).mp heα]
    have hsubset : alphaRel a ⊆ ({e} : Set E) := by
      simpa [Adj.sigma_star_induced, hEq] using haSigSingleton
    refine ⟨e, ?_⟩
    ext e'
    constructor
    · intro he'
      exact hsubset he'
    · intro he'
      simpa using he' ▸ heα
  · intro hsingle
    funext X
    ext a
    constructor
    · intro haSig
      rcases (by
        simpa [Adj.sigma_star] using haSig : ∃ e, e ∈ X ∧ a ∈ sigmaRel e) with
        ⟨e, heX, haσ⟩
      rcases hsingle a with ⟨e₀, hα⟩
      intro e' he'
      have heq : e' = e₀ := by
        simpa [hα] using he'
      have hee₀ : e = e₀ := by
        simpa [hα] using (hConv a e).mpr haσ
      simpa [heq] using (hee₀ ▸ heX)
    · intro hsubset
      rcases hsingle a with ⟨e, hα⟩
      have heα : e ∈ alphaRel a := by
        simpa [hα]
      have heX : e ∈ X := hsubset heα
      have haσ : a ∈ sigmaRel e := (hConv a e).mp heα
      exact (by
        simpa [Adj.sigma_star] using ⟨e, heX, haσ⟩)

/-- v5.2 §21.2 public name: disappearance of the ∃/∀ gap is exactly
single-valued degeneracy of every action image. -/
theorem degenerate_iff {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) :
    Adj.sigma_star sigmaRel = Adj.sigma_star_induced alphaRel ↔
      ∀ a, SingletonImage alphaRel a :=
  sigma_star_eq_induced_iff_singleton hConv

theorem identification_forces_singleton {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    (hEq : Adj.sigma_star sigmaRel = Adj.sigma_star_induced alphaRel)
    (a : M) : SingletonImage alphaRel a :=
  (sigma_star_eq_induced_iff_singleton hConv).mp hEq a

/-- v5.2 §21.4 public name: identifying the existential and universal lifts
forces pointwise degeneracy. -/
theorem identification_forces_degeneracy {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    (hEq : Adj.sigma_star sigmaRel = Adj.sigma_star_induced alphaRel) :
    ∀ a, SingletonImage alphaRel a :=
  (degenerate_iff hConv).mp hEq

theorem no_gapUp_under_identification {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    (hEq : Adj.sigma_star sigmaRel = Adj.sigma_star_induced alphaRel)
    (a : M) : ¬ GapUp alphaRel sigmaRel a := by
  intro hgap
  rcases identification_forces_singleton hConv hEq a with ⟨e, hα⟩
  rcases (gapUp_iff_branch hConv a).mp hgap with
    ⟨e₁, e₂, he₁, he₂, hne⟩
  have he₁eq : e₁ = e := by
    simpa [hα] using he₁
  have he₂eq : e₂ = e := by
    simpa [hα] using he₂
  exact hne (he₁eq.trans he₂eq.symm)

theorem no_gapDn_under_identification {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    (hEq : Adj.sigma_star sigmaRel = Adj.sigma_star_induced alphaRel)
    (a : M) : ¬ GapDn alphaRel sigmaRel a := by
  intro hgap
  rcases identification_forces_singleton hConv hEq a with ⟨e, hα⟩
  have hnonempty : (alphaRel a).Nonempty := by
    exact ⟨e, by simp [hα]⟩
  have hempty : alphaRel a = ∅ := (gapDn_iff_empty hConv a).mp hgap
  simpa [hempty] using hnonempty

theorem singleton_not_branch {M E : Type*}
    {alphaRel : M → Set E} {a : M}
    (hsingle : SingletonImage alphaRel a) :
    ¬ Richness.Branch alphaRel a := by
  rintro ⟨e₁, e₂, he₁, he₂, hne⟩
  rcases hsingle with ⟨e, hα⟩
  have he₁eq : e₁ = e := by
    simpa [hα] using he₁
  have he₂eq : e₂ = e := by
    simpa [hα] using he₂
  exact hne (he₁eq.trans he₂eq.symm)

theorem singleton_not_gapUp {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    {a : M} (hsingle : SingletonImage alphaRel a) :
    ¬ GapUp alphaRel sigmaRel a := by
  intro hgap
  exact singleton_not_branch hsingle ((gapUp_iff_branch hConv a).mp hgap)

theorem singleton_not_gapDn {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    {a : M} (hsingle : SingletonImage alphaRel a) :
    ¬ GapDn alphaRel sigmaRel a := by
  intro hgap
  rcases hsingle with ⟨e, hα⟩
  have hnonempty : (alphaRel a).Nonempty := ⟨e, by simp [hα]⟩
  have hempty : alphaRel a = ∅ := (gapDn_iff_empty hConv a).mp hgap
  simpa [hempty] using hnonempty

theorem singleton_of_nonempty_not_branch {M E : Type*}
    {alphaRel : M → Set E} {a : M}
    (hnonempty : (alphaRel a).Nonempty)
    (hnbranch : ¬ Richness.Branch alphaRel a) :
    SingletonImage alphaRel a := by
  rcases hnonempty with ⟨e, he⟩
  refine ⟨e, ?_⟩
  ext e'
  constructor
  · intro he'
    by_cases heq : e' = e
    · simpa [heq]
    · have hbranch : Richness.Branch alphaRel a :=
        ⟨e, e', he, he', fun h => heq h.symm⟩
      exact False.elim (hnbranch hbranch)
  · intro he'
    simpa using he' ▸ he

theorem no_gap_iff_singleton {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) (a : M) :
    (¬ GapUp alphaRel sigmaRel a ∧ ¬ GapDn alphaRel sigmaRel a) ↔
      SingletonImage alphaRel a := by
  constructor
  · rintro ⟨hnup, hndn⟩
    have hnbranch : ¬ Richness.Branch alphaRel a := by
      intro hbranch
      exact hnup ((gapUp_iff_branch hConv a).mpr hbranch)
    have hnonempty : (alphaRel a).Nonempty := by
      by_contra hnone
      have hempty : alphaRel a = ∅ := by
        ext e
        constructor
        · intro he
          exact False.elim (hnone ⟨e, he⟩)
        · intro h
          exact False.elim (by simpa using h)
      exact hndn ((gapDn_iff_empty hConv a).mpr hempty)
    exact singleton_of_nonempty_not_branch hnonempty hnbranch
  · intro hsingle
    exact ⟨singleton_not_gapUp hConv hsingle, singleton_not_gapDn hConv hsingle⟩

theorem gap_trichotomy {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) (a : M) :
    GapDn alphaRel sigmaRel a ∨
      SingletonImage alphaRel a ∨
      GapUp alphaRel sigmaRel a := by
  by_cases hempty : alphaRel a = ∅
  · exact Or.inl ((gapDn_iff_empty hConv a).mpr hempty)
  · by_cases hbranch : Richness.Branch alphaRel a
    · exact Or.inr (Or.inr ((gapUp_iff_branch hConv a).mpr hbranch))
    · have hnonempty : (alphaRel a).Nonempty := by
        by_contra hnone
        apply hempty
        ext e
        constructor
        · intro he
          exact False.elim (hnone ⟨e, he⟩)
        · intro h
          exact False.elim (by simpa using h)
      exact Or.inr (Or.inl (singleton_of_nonempty_not_branch hnonempty hbranch))

theorem branch_iff_gapUp {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) (a : M) :
    Richness.Branch alphaRel a ↔ GapUp alphaRel sigmaRel a :=
  (gapUp_iff_branch hConv a).symm

theorem gapUp_alpha_nonempty {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    {a : M} (hgap : GapUp alphaRel sigmaRel a) :
    (alphaRel a).Nonempty := by
  rcases (gapUp_iff_branch hConv a).mp hgap with
    ⟨e₁, _e₂, he₁, _he₂, _hne⟩
  exact ⟨e₁, he₁⟩

theorem gapUp_alpha_two {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e)
    {a : M} (hgap : GapUp alphaRel sigmaRel a) :
    ∃ e₁ e₂, e₁ ∈ alphaRel a ∧ e₂ ∈ alphaRel a ∧ e₁ ≠ e₂ := by
  exact (gapUp_iff_branch hConv a).mp hgap

/-- v5.2 §21.3 public name for the upward gap characterization. -/
theorem gapUp_iff {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) (a : M) :
    GapUp alphaRel sigmaRel a ↔ Richness.Branch alphaRel a :=
  gapUp_iff_branch hConv a

/-- v5.2 §21.3 public name for the downward gap characterization. -/
theorem gapDn_iff {M E : Type*}
    {alphaRel : M → Set E} {sigmaRel : E → Set M}
    (hConv : ∀ a e, e ∈ alphaRel a ↔ a ∈ sigmaRel e) (a : M) :
    GapDn alphaRel sigmaRel a ↔ alphaRel a = ∅ :=
  gapDn_iff_empty hConv a

end Gap
end ERIEC
