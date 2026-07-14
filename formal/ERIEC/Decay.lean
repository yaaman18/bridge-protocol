import ERIEC.Dynamics

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

/-- The simultaneous update obtained by replacing both canonical intersections
with substrate-independent contraction operators. -/
def upd_dec {C E W : Type*}
    (dec : W → Set C → Set C) (decE : W → Set E → Set E)
    (drift : W → Set C → W) (c : Dynamics.Conf C E W) :
    Dynamics.Conf C E W :=
  ⟨dec c.rank c.kappa, decE c.rank c.epsilon, drift c.rank c.kappa⟩

/-- The generalized update decreases the intrinsic component. -/
theorem upd_dec_kappa_subset {C E W : Type*}
    {family : Grading.RankedClosure W C}
    (dec : ∀ w, DecayStructure (family.op w))
    (decE : W → Set E → Set E) (drift : W → Set C → W)
    (c : Dynamics.Conf C E W) :
    (upd_dec (fun w ↦ (dec w).dec) decE drift c).kappa ⊆ c.kappa :=
  dec_subset (dec c.rank) c.kappa

/-- While the intrinsic component is nonempty, either rank progress or strict
decay decreases the same finite measure used by the canonical update. -/
theorem collapseMeasure_upd_dec_lt {C E W : Type*}
    [Finite C] [Finite W] [LinearOrder W] [OrderTop W]
    (family : Grading.RankedClosure W C)
    (dec : ∀ w, DecayStructure (family.op w))
    (decE : W → Set E → Set E) (drift : W → Set C → W)
    (r2 : Dynamics.R2Prime drift) (threshold : W)
    (hThreshold : threshold < ⊤) (hSig2 : Grading.sig2 family threshold)
    (c : Dynamics.Conf C E W) (hKappa : c.kappa.Nonempty) :
    Dynamics.collapseMeasure (upd_dec (fun w ↦ (dec w).dec) decE drift c) <
      Dynamics.collapseMeasure c := by
  have hCoreLe :
      (upd_dec (fun w ↦ (dec w).dec) decE drift c).kappa.ncard ≤
        c.kappa.ncard :=
    Set.ncard_le_ncard (upd_dec_kappa_subset dec decE drift c)
  by_cases hTop : c.rank = ⊤
  · have hDrift : drift c.rank c.kappa = c.rank := by
      rw [hTop]
      exact le_antisymm le_top (r2.nondecreasing ⊤ c.kappa)
    have hNotPost : ¬ c.kappa ⊆ family.op c.rank c.kappa := by
      rw [hTop]
      exact hSig2 ⊤ hThreshold c.kappa hKappa
    have hCoreStrict :
        (upd_dec (fun w ↦ (dec w).dec) decE drift c).kappa.ncard <
          c.kappa.ncard :=
      Set.ncard_lt_ncard ((dec c.rank).strict_of_not_postfixed hNotPost)
    simp only [Dynamics.collapseMeasure, upd_dec, hDrift]
    exact Nat.add_lt_add_left hCoreStrict _
  · have hRank : c.rank < drift c.rank c.kappa :=
      r2.strict_of_nonempty c.rank c.kappa hKappa hTop
    have hRankStrict := Dynamics.Ioi_ncard_strict_anti hRank
    simp only [Dynamics.collapseMeasure, upd_dec]
    exact Nat.add_lt_add_of_lt_of_le hRankStrict hCoreLe

/-- Empty intrinsic configurations remain empty under generalized decay. -/
theorem upd_dec_empty_absorbing {C E W : Type*}
    {family : Grading.RankedClosure W C}
    (dec : ∀ w, DecayStructure (family.op w))
    (decE : W → Set E → Set E) (drift : W → Set C → W)
    (c : Dynamics.Conf C E W) (hEmpty : c.kappa = ∅) :
    (upd_dec (fun w ↦ (dec w).dec) decE drift c).kappa = ∅ := by
  simp only [upd_dec]
  rw [hEmpty]
  exact (dec c.rank).empty

theorem iterate_upd_dec_empty_absorbing {C E W : Type*}
    {family : Grading.RankedClosure W C}
    (dec : ∀ w, DecayStructure (family.op w))
    (decE : W → Set E → Set E) (drift : W → Set C → W)
    (c : Dynamics.Conf C E W) (hEmpty : c.kappa = ∅) :
    ∀ n, (((upd_dec (fun w ↦ (dec w).dec) decE drift)^[n]) c).kappa = ∅ := by
  intro n
  induction n generalizing c with
  | zero => exact hEmpty
  | succ n ih =>
      rw [Function.iterate_succ_apply]
      exact ih _ (upd_dec_empty_absorbing dec decE drift c hEmpty)

/-- v5.2 §22.4: every substrate-independent decay satisfying d1 and d4
reaches a permanent empty intrinsic component within `|W| + |C|` updates. -/
theorem abstract_collapse {C E W : Type*}
    [Finite C] [Finite W] [LinearOrder W] [OrderTop W]
    (family : Grading.RankedClosure W C)
    (dec : ∀ w, DecayStructure (family.op w))
    (decE : W → Set E → Set E) (drift : W → Set C → W)
    (r2 : Dynamics.R2Prime drift) (threshold : W)
    (hThreshold : threshold < ⊤) (hSig2 : Grading.sig2 family threshold)
    (c0 : Dynamics.Conf C E W) :
    ∃ n ≤ Nat.card W + Nat.card C, ∀ k, n ≤ k →
      (((upd_dec (fun w ↦ (dec w).dec) decE drift)^[k]) c0).kappa = ∅ := by
  let update : Dynamics.Conf C E W → Dynamics.Conf C E W :=
    upd_dec (fun w ↦ (dec w).dec) decE drift
  have reachesEmpty : ∀ c : Dynamics.Conf C E W,
      ∃ n ≤ Dynamics.collapseMeasure c, ((update^[n]) c).kappa = ∅ := by
    intro c
    let motive : Dynamics.Conf C E W → Prop := fun c ↦
      ∃ n ≤ Dynamics.collapseMeasure c, ((update^[n]) c).kappa = ∅
    change motive c
    refine (measure Dynamics.collapseMeasure).wf.induction c ?_
    intro c ih
    by_cases hEmpty : c.kappa = ∅
    · exact ⟨0, Nat.zero_le _, by simp [hEmpty]⟩
    · have hNonempty : c.kappa.Nonempty := Set.nonempty_iff_ne_empty.mpr hEmpty
      have hDecrease : Dynamics.collapseMeasure (update c) <
          Dynamics.collapseMeasure c := by
        exact collapseMeasure_upd_dec_lt family dec decE drift r2 threshold
          hThreshold hSig2 c hNonempty
      obtain ⟨n, hn, hAtN⟩ := ih (update c) hDecrease
      refine ⟨n + 1, ?_, ?_⟩
      · exact (Nat.succ_le_succ hn).trans (Nat.succ_le_iff.mpr hDecrease)
      · simpa [update, Function.iterate_succ_apply] using hAtN
  obtain ⟨n, hnMeasure, hAtN⟩ := reachesEmpty c0
  have hMeasureBound :
      Dynamics.collapseMeasure c0 ≤ Nat.card W + Nat.card C := by
    unfold Dynamics.collapseMeasure
    exact Nat.add_le_add (Set.ncard_le_card (Set.Ioi c0.rank))
      (Set.ncard_le_card c0.kappa)
  refine ⟨n, hnMeasure.trans hMeasureBound, ?_⟩
  intro k hnk
  obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hnk
  rw [Nat.add_comm, Function.iterate_add_apply]
  exact iterate_upd_dec_empty_absorbing dec decE drift
    (((update^[n]) c0)) hAtN d

theorem nu_fixed {C : Type*} {F : Set C → Set C}
    (D : DecayStructure F) (hmono : Monotone F) :
    D.dec (Closure.nu F) = Closure.nu F :=
  D.fixed_of_postfixed (Closure.nu_postfixed hmono)

theorem psi_recovers_fixed {C : Type*} {F : Set C → Set C}
    (hmono : Monotone F) :
    (psi_isDecay (C := C) hmono).dec (Closure.nu F) = Closure.nu F :=
  nu_fixed (psi_isDecay hmono) hmono

/-- v5.2 §22.4′: the canonical `Ψ` update is the standard instance of
the substrate-independent collapse theorem. -/
theorem collapse_of_psi {C E W : Type*}
    [Finite C] [Finite W] [LinearOrder W] [OrderTop W]
    (family : Grading.RankedClosure W C)
    (theta : W → Set E → Set E) (drift : W → Set C → W)
    (r2 : Dynamics.R2Prime drift) (threshold : W)
    (hThreshold : threshold < ⊤) (hSig2 : Grading.sig2 family threshold)
    (c0 : Dynamics.Conf C E W) :
    ∃ n ≤ Nat.card W + Nat.card C, ∀ k, n ≤ k →
      (((Dynamics.upd family.op theta drift)^[k]) c0).kappa = ∅ :=
  Dynamics.collapse_conf family theta drift r2 threshold hThreshold hSig2 c0

end Decay
end ERIEC
