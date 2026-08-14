import ERIEC.Wager.Basic
import Mathlib.Data.Set.Finite.Lattice
import Mathlib.Order.Preorder.Finite
import Mathlib.Order.RelSeries

namespace ERIEC
namespace Wager

private def relationSet {S : Type*} (step : S → S → Prop) : SetRel S S :=
  {pair | step pair.1 pair.2}

private theorem transGen_of_nat_steps {S : Type*} {step : S → S → Prop}
    (traj : ℕ → S) (hstep : ∀ n, step (traj n) (traj (n + 1)))
    {i j : ℕ} (hij : i < j) : Relation.TransGen step (traj i) (traj j) := by
  induction j with
  | zero => omega
  | succ j ih =>
      rcases Nat.lt_or_eq_of_le (Nat.le_of_lt_succ hij) with hij' | rfl
      · exact Relation.TransGen.tail (ih hij') (by
          simpa only [Nat.succ_eq_add_one] using hstep j)
      · simpa only [Nat.succ_eq_add_one] using Relation.TransGen.single (hstep i)

private def singleStepSeries {S : Type*} {step : S → S → Prop}
    {a b : S} (hab : step a b) : RelSeries (relationSet step) where
  length := 1
  toFun := Fin.cases a (fun _ => b)
  step i := by
    have hi : i = 0 := Fin.eq_zero i
    subst i
    exact hab

private theorem singleStepSeries_head {S : Type*} {step : S → S → Prop}
    {a b : S} (hab : step a b) : (singleStepSeries hab).head = a := by
  rfl

private theorem singleStepSeries_last {S : Type*} {step : S → S → Prop}
    {a b : S} (hab : step a b) : (singleStepSeries hab).last = b := by
  rfl

private theorem exists_series_of_transGen {S : Type*} {step : S → S → Prop}
    {a b : S} (h : Relation.TransGen step a b) :
    ∃ p : RelSeries (relationSet step),
      0 < p.length ∧ p.head = a ∧ p.last = b := by
  induction h with
  | single hab =>
      exact ⟨singleStepSeries hab, Nat.zero_lt_one,
        singleStepSeries_head hab, singleStepSeries_last hab⟩
  | tail _ hbc ih =>
      obtain ⟨p, hpos, hhead, hlast⟩ := ih
      let q := p.snoc _ (hlast ▸ hbc)
      refine ⟨q, ?_, ?_, ?_⟩
      · rw [RelSeries.snoc_length]
        omega
      · exact (RelSeries.head_snoc p _ (hlast ▸ hbc)).trans hhead
      · exact RelSeries.last_snoc p _ (hlast ▸ hbc)

private noncomputable def seriesOfTransGen {S : Type*} {step : S → S → Prop}
    {a b : S} (h : Relation.TransGen step a b) :
    RelSeries (relationSet step) :=
  Classical.choose (exists_series_of_transGen h)

private theorem seriesOfTransGen_length_pos {S : Type*} {step : S → S → Prop}
    {a b : S} (h : Relation.TransGen step a b) : 0 < (seriesOfTransGen h).length := by
  exact (Classical.choose_spec (exists_series_of_transGen h)).1

private theorem seriesOfTransGen_head {S : Type*} {step : S → S → Prop}
    {a b : S} (h : Relation.TransGen step a b) : (seriesOfTransGen h).head = a := by
  exact (Classical.choose_spec (exists_series_of_transGen h)).2.1

private theorem seriesOfTransGen_last {S : Type*} {step : S → S → Prop}
    {a b : S} (h : Relation.TransGen step a b) : (seriesOfTransGen h).last = b := by
  exact (Classical.choose_spec (exists_series_of_transGen h)).2.2

private def periodicTrajectory {S : Type*} {step : S → S → Prop}
    (p : RelSeries (relationSet step)) (hpos : 0 < p.length) : ℕ → S :=
  fun n => p ⟨n % p.length, (Nat.mod_lt n hpos).trans (Nat.lt_succ_self _)⟩

private theorem periodicTrajectory_zero {S : Type*} {step : S → S → Prop}
    (p : RelSeries (relationSet step)) (hpos : 0 < p.length) :
    periodicTrajectory p hpos 0 = p.head := by
  change p 0 = p.head
  exact RelSeries.apply_zero p

private theorem periodicTrajectory_step {S : Type*} {step : S → S → Prop}
    (p : RelSeries (relationSet step)) (hpos : 0 < p.length)
    (hclosed : p.last = p.head) :
    ∀ n, step (periodicTrajectory p hpos n) (periodicTrajectory p hpos (n + 1)) := by
  intro n
  let i := n % p.length
  have hi : i < p.length := Nat.mod_lt n hpos
  by_cases hnext : i + 1 < p.length
  · have hmod : (n + 1) % p.length = i + 1 := by
      rw [Nat.add_mod]
      have hone : 1 % p.length = 1 := Nat.mod_eq_of_lt (by omega)
      rw [hone, Nat.mod_eq_of_lt hnext]
    have hedge := p.step ⟨i, hi⟩
    change step (p ⟨i, _⟩) (p ⟨i + 1, _⟩) at hedge
    change step (p ⟨n % p.length, _⟩) (p ⟨(n + 1) % p.length, _⟩)
    convert hedge using 1
    apply congr_arg p
    apply Fin.ext
    exact hmod
  · have hilast : i + 1 = p.length := by omega
    have hmod : (n + 1) % p.length = 0 := by
      by_cases hlength : p.length = 1
      · rw [hlength, Nat.mod_one]
      · rw [Nat.add_mod]
        have hone : 1 % p.length = 1 := Nat.mod_eq_of_lt (by omega)
        rw [hone, hilast, Nat.mod_self]
    have hedge := p.step ⟨i, hi⟩
    change step (p ⟨i, _⟩) (p ⟨i + 1, _⟩) at hedge
    have htarget : p ⟨(n + 1) % p.length, by omega⟩ = p.head := by
      rw [← RelSeries.apply_zero p]
      apply congr_arg p
      apply Fin.ext
      exact hmod
    change step (p ⟨i, _⟩) (p ⟨(n + 1) % p.length, _⟩)
    rw [htarget, ← hclosed]
    convert hedge using 1
    rw [← RelSeries.apply_last p]
    apply congr_arg p
    apply Fin.ext
    exact hilast.symm

theorem W6_to_exists_dc_transGen_self {A E C S : Type*} [Finite S]
    (impl : FrozenImpl A E C S) :
    W6 impl → ∃ s, impl.dc s ∧ Relation.TransGen impl.step s s := by
  rintro ⟨traj, hstep, hrecur⟩
  let hits : Set ℕ := {n | impl.dc (traj n)}
  have hhits : hits.Infinite := by
    apply Set.infinite_of_not_bddAbove
    rintro ⟨bound, hbound⟩
    obtain ⟨m, hbm, hdc⟩ := hrecur (bound + 1)
    have hmle : m ≤ bound := hbound hdc
    omega
  obtain ⟨i, hi, j, hj, hij, heq⟩ :=
    hhits.exists_lt_map_eq_of_mapsTo (Set.mapsTo_univ traj hits) Set.finite_univ
  refine ⟨traj j, hj, ?_⟩
  have hpath := transGen_of_nat_steps traj hstep hij
  rw [heq] at hpath
  exact hpath

theorem W6_of_exists_dc_transGen_self {A E C S : Type*}
    (impl : FrozenImpl A E C S) :
    (∃ s, impl.dc s ∧ Relation.TransGen impl.step s s) → W6 impl := by
  rintro ⟨s, hdc, hcycle⟩
  let p := seriesOfTransGen hcycle
  have hpos : 0 < p.length := seriesOfTransGen_length_pos hcycle
  have hhead : p.head = s := seriesOfTransGen_head hcycle
  have hlast : p.last = s := seriesOfTransGen_last hcycle
  have hclosed : p.last = p.head := hlast.trans hhead.symm
  refine ⟨periodicTrajectory p hpos, periodicTrajectory_step p hpos hclosed, ?_⟩
  intro n
  have hnle : n ≤ p.length * (n + 1) :=
    (Nat.le_mul_of_pos_left n hpos).trans
      (Nat.mul_le_mul_left p.length (Nat.le_succ n))
  refine ⟨p.length * (n + 1), hnle, ?_⟩
  have hmod : p.length * (n + 1) % p.length = 0 := Nat.mul_mod_right _ _
  have htraj0 : periodicTrajectory p hpos (p.length * (n + 1)) =
      periodicTrajectory p hpos 0 := by
    apply congr_arg p
    apply Fin.ext
    exact hmod
  rw [htraj0, periodicTrajectory_zero p hpos, hhead]
  exact hdc

theorem W6_iff_dc_transGen_self {A E C S : Type*} [Finite S]
    (impl : FrozenImpl A E C S) :
    W6 impl ↔ ∃ s, impl.dc s ∧ Relation.TransGen impl.step s s :=
  ⟨W6_to_exists_dc_transGen_self impl, W6_of_exists_dc_transGen_self impl⟩

end Wager
end ERIEC
