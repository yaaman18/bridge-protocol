import ERIEC.TemporalDC
import ERIEC.Decay
import ERIEC.DC
import ERIEC.RefModel.LineageWitness

namespace ERIEC
namespace RefModel

open OpenEvolution

/-- Every DC certificate has a nonempty intrinsic component at its selected
state.  This is the direct bridge from `DC.hBound` to collapse traces. -/
theorem dc_selected_kappa_nonempty {M E C S : Type*} (dc : DC M E C S) :
    (dc.kappa dc.s).Nonempty :=
  dc.hBound.mono Set.inter_subset_left

/-- The finite reference certificate before collapse. -/
def collapseInitialDC : DC (Fin 1) Unit Unit (Fin 1) :=
  richLineageDC 0

def collapseInitial : Dynamics.Conf Unit Unit Unit :=
  ⟨Set.univ, Set.univ, ()⟩

def collapseDec (_ : Unit) (_ : Set Unit) : Set Unit := ∅
def collapseDecE (_ : Unit) (E : Set Unit) : Set Unit := E
def collapseDrift (_ : Unit) (_ : Set Unit) : Unit := ()

def collapseUpdate : Dynamics.Conf Unit Unit Unit → Dynamics.Conf Unit Unit Unit :=
  Decay.upd_dec collapseDec collapseDecE collapseDrift

def collapseState (n : Nat) : Dynamics.Conf Unit Unit Unit :=
  (collapseUpdate^[n]) collapseInitial

/-- A state is certified only when some actual DC certificate realizes its
intrinsic component. -/
def CollapseConfigurationCertified (c : Dynamics.Conf Unit Unit Unit) : Prop :=
  ∃ dc : DC (Fin 1) Unit Unit (Fin 1), dc.kappa dc.s = c.kappa

theorem collapseState_zero_certified :
    CollapseConfigurationCertified (collapseState 0) := by
  exact ⟨collapseInitialDC, rfl⟩

theorem collapseState_succ_kappa_empty (n : Nat) :
    (collapseState (n + 1)).kappa = ∅ := by
  change ((collapseUpdate^[Nat.succ n]) collapseInitial).kappa = ∅
  rw [Function.iterate_succ_apply']
  rfl

theorem collapseState_certified_iff_zero (n : Nat) :
    CollapseConfigurationCertified (collapseState n) ↔ n = 0 := by
  constructor
  · rintro ⟨dc, hdc⟩
    cases n with
    | zero => rfl
    | succ n =>
        have hempty : (collapseState (n + 1)).kappa = ∅ :=
          collapseState_succ_kappa_empty n
        have hnonempty := dc_selected_kappa_nonempty dc
        rw [hdc, hempty] at hnonempty
        exact False.elim (Set.not_nonempty_empty hnonempty)
  · rintro rfl
    exact collapseState_zero_certified

abbrev collapseOpenSystem : OpenSystem.{0} where
  Fast := Dynamics.Conf Unit Unit Unit
  Slow := Unit
  Env := Unit
  step := fun c => {(collapseUpdate c.1, ((), ()))}

abbrev collapseGeneratedTrace :
    TemporalDC.GeneratedTrace.{0, 0} collapseOpenSystem where
  Occurrence := Nat
  state := fun n => (collapseState n, ((), ()))
  next := fun n m => m = n + 1
  generated := by
    intro n m hnm
    subst m
    rw [Set.mem_singleton_iff]
    simp [collapseState, Function.iterate_succ_apply']

abbrev collapseCertification :
    TemporalDC.Certification collapseGeneratedTrace where
  dcHolds := fun n => CollapseConfigurationCertified (collapseState n)

theorem collapse_reachable_from_one_ne_zero {z : Nat}
    (h : TemporalDC.Reachable collapseGeneratedTrace.next 1 z) : z ≠ 0 := by
  induction h with
  | refl => exact Nat.one_ne_zero
  | tail _ hnext _ =>
      rw [hnext]
      exact Nat.succ_ne_zero _

theorem collapse_permanent :
    collapseCertification.PermanentTerminationStep 0 1 := by
  refine ⟨?_, ?_⟩
  · exact ⟨rfl, collapseState_zero_certified,
      fun h => Nat.one_ne_zero ((collapseState_certified_iff_zero 1).mp h)⟩
  · intro z hz hcert
    exact collapse_reachable_from_one_ne_zero hz
      ((collapseState_certified_iff_zero z).mp hcert)

/-- Concrete TemporalDC trace whose states are iterations of `upd_dec`, with
an actual DC certificate at the initial state and a permanently empty
intrinsic component after its first generated transition. -/
structure CollapseTraceWitness : Type 1 where
  A : OpenSystem.{0}
  trace : TemporalDC.GeneratedTrace.{0, 0} A
  cert : TemporalDC.Certification trace
  x : trace.Occurrence
  y : trace.Occurrence
  certified_start : cert.dcHolds x
  permanent : cert.PermanentTerminationStep x y

/-- VP-TMP-003: a structurally absorbing collapse trace exists. -/
theorem collapse_trace_reference_model : Nonempty CollapseTraceWitness := by
  exact ⟨{
    A := collapseOpenSystem
    trace := collapseGeneratedTrace
    cert := collapseCertification
    x := 0
    y := 1
    certified_start := collapseState_zero_certified
    permanent := collapse_permanent
  }⟩

theorem collapse_certified_eq_zero {n : Nat}
    (h : collapseCertification.dcHolds n) : n = 0 :=
  (collapseState_certified_iff_zero n).mp h

theorem collapse_trace_precarious : collapseCertification.Precarious := by
  intro x hx
  have hx0 : x = 0 := collapse_certified_eq_zero hx
  subst x
  exact ⟨0, 1, .refl 0, collapse_permanent.1⟩

structure AllMortalWitness : Type 1 where
  toCollapseTraceWitness : CollapseTraceWitness
  no_escape : toCollapseTraceWitness.cert.NoInternalEscape

theorem collapse_no_internal_escape : collapseCertification.NoInternalEscape := by
  intro x hx
  have hx0 : x = 0 := collapse_certified_eq_zero hx
  subst x
  exact ⟨0, 1, .refl 0, collapse_permanent⟩

/-- VP-TMP-005: the target theory admits a reference trace with no certified
internal escape from permanent functional termination. -/
theorem all_mortal_reference_model : Nonempty AllMortalWitness := by
  exact ⟨{
    toCollapseTraceWitness := {
      A := collapseOpenSystem
      trace := collapseGeneratedTrace
      cert := collapseCertification
      x := 0
      y := 1
      certified_start := collapseState_zero_certified
      permanent := collapse_permanent
    }
    no_escape := collapse_no_internal_escape
  }⟩

end RefModel
end ERIEC
