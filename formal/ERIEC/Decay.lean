import ERIEC.Closure

namespace ERIEC
namespace Decay

/-- Standard contraction associated with a monotone closure operator. -/
def psi {C : Type*} (F : Set C → Set C) (Y : Set C) : Set C :=
  Y ∩ F Y

theorem psi_subset {C : Type*} (F : Set C → Set C) (Y : Set C) :
    psi F Y ⊆ Y := by
  intro x hx
  exact hx.1

theorem psi_eq_of_postfixed {C : Type*} {F : Set C → Set C} {Y : Set C}
    (hpost : Y ⊆ F Y) : psi F Y = Y := by
  ext x
  constructor
  · intro hx
    exact hx.1
  · intro hx
    exact ⟨hx, hpost hx⟩

theorem psi_strict_of_not_postfixed {C : Type*} {F : Set C → Set C} {Y : Set C}
    (hnot : ¬ Y ⊆ F Y) : psi F Y ⊂ Y := by
  refine Set.ssubset_iff_subset_ne.mpr ⟨psi_subset F Y, ?_⟩
  intro heq
  rcases Set.not_subset.mp hnot with ⟨x, hxY, hxnotF⟩
  have hxPsi : x ∈ psi F Y := heq.symm ▸ hxY
  exact hxnotF hxPsi.2

theorem psi_mono {C : Type*} {F : Set C → Set C} (hmono : Monotone F) :
    Monotone (psi F) := by
  intro Y Z hYZ x hx
  exact ⟨hYZ hx.1, hmono hYZ hx.2⟩

/-- The second iterate of the standard contraction. -/
def psi2 {C : Type*} (F : Set C → Set C) (Y : Set C) : Set C :=
  psi F (psi F Y)

/-- A local decay structure over an operator `F`. The fields are local
assumptions of the structure, not new global axioms. -/
structure DecayStructure {C : Type*} (F : Set C → Set C) where
  dec : Set C → Set C
  empty : dec ∅ = ∅
  mono : Monotone dec
  fixed_of_postfixed : ∀ {Y : Set C}, Y ⊆ F Y → dec Y = Y
  strict_of_not_postfixed : ∀ {Y : Set C}, ¬ Y ⊆ F Y → dec Y ⊂ Y

def psi_isDecay {C : Type*} {F : Set C → Set C} (hmono : Monotone F) :
    DecayStructure F where
  dec := psi F
  empty := by
    ext x
    simp [psi]
  mono := by
    exact psi_mono hmono
  fixed_of_postfixed := by
    intro Y hpost
    ext x
    constructor
    · intro hx
      exact hx.1
    · intro hx
      exact ⟨hx, hpost hx⟩
  strict_of_not_postfixed := by
    intro Y hnot
    refine Set.ssubset_iff_subset_ne.mpr ⟨?_, ?_⟩
    · intro x hx
      exact hx.1
    · intro heq
      rcases Set.not_subset.mp hnot with ⟨x, hxY, hxnotF⟩
      have hxPsi : x ∈ psi F Y := heq.symm ▸ hxY
      exact hxnotF hxPsi.2

def psi2_isDecay {C : Type*} {F : Set C → Set C} (hmono : Monotone F) :
    DecayStructure F where
  dec := psi2 F
  empty := by
    simp [psi2, psi]
  mono := by
    exact (psi_mono hmono).comp (psi_mono hmono)
  fixed_of_postfixed := by
    intro Y hpost
    simp [psi2, psi_eq_of_postfixed hpost]
  strict_of_not_postfixed := by
    intro Y hnot
    have hstrict : psi F Y ⊂ Y := psi_strict_of_not_postfixed hnot
    refine Set.ssubset_iff_subset_ne.mpr ⟨?_, ?_⟩
    · intro x hx
      exact hstrict.subset (psi_subset F (psi F Y) hx)
    · intro heq
      rcases Set.ssubset_iff_subset_ne.mp hstrict with ⟨hsub, hne⟩
      apply hne
      ext x
      constructor
      · intro hx
        exact hsub hx
      · intro hx
        have hxPsi2 : x ∈ psi2 F Y := heq.symm ▸ hx
        exact psi_subset F (psi F Y) hxPsi2

theorem core_fixed {C : Type*} {F : Set C → Set C}
    (D : DecayStructure F) {Y : Set C} (hpost : Y ⊆ F Y) :
    D.dec Y = Y :=
  D.fixed_of_postfixed hpost

theorem dec_subset {C : Type*} {F : Set C → Set C}
    (D : DecayStructure F) (Y : Set C) :
    D.dec Y ⊆ Y := by
  by_cases hpost : Y ⊆ F Y
  · rw [D.fixed_of_postfixed hpost]
  · exact (D.strict_of_not_postfixed hpost).subset

theorem dec_eq_or_strict {C : Type*} {F : Set C → Set C}
    (D : DecayStructure F) (Y : Set C) :
    D.dec Y = Y ∨ D.dec Y ⊂ Y := by
  by_cases hpost : Y ⊆ F Y
  · exact Or.inl (D.fixed_of_postfixed hpost)
  · exact Or.inr (D.strict_of_not_postfixed hpost)

theorem nu_fixed {C : Type*} {F : Set C → Set C}
    (D : DecayStructure F) (hmono : Monotone F) :
    D.dec (Closure.nu F) = Closure.nu F :=
  D.fixed_of_postfixed (Closure.nu_postfixed hmono)

theorem psi_recovers_fixed {C : Type*} {F : Set C → Set C}
    (hmono : Monotone F) :
    (psi_isDecay (C := C) hmono).dec (Closure.nu F) = Closure.nu F :=
  nu_fixed (psi_isDecay hmono) hmono

end Decay
end ERIEC
