import ERIEC.Wager.Basic

namespace ERIEC
namespace Wager

theorem W1_indep {A E C S : Type*} (impl : FrozenImpl A E C S) (s0 : S)
    (hleft : impl.dc s0 ∧ impl.nontrivial) :
    (∃ Ph, W1 impl Ph) ∧ (∃ Ph, ¬ W1 impl Ph) := by
  constructor
  · exact ⟨fun s => impl.dc s ∧ impl.nontrivial, fun _ => Iff.rfl⟩
  · refine ⟨fun _ => False, ?_⟩
    intro h
    exact (h s0).mp hleft

theorem W2_indep {A E C S : Type*} (impl : FrozenImpl A E C S) (s0 : S) (e0 : E)
    (hdc : impl.dc s0) (hpos : impl.positiveValue s0 e0) :
    (∃ Mat, W2 impl Mat) ∧ (∃ Mat, ¬ W2 impl Mat) := by
  constructor
  · exact ⟨impl.positiveValue, fun _ _ _ => Iff.rfl⟩
  · refine ⟨fun _ _ => False, ?_⟩
    intro h
    exact (h s0 hdc e0).mp hpos

theorem W3_indep {A E C S : Type*} (impl : FrozenImpl A E C S) (s0 : S)
    (hconscious : impl.consciousHinge s0) :
    (∃ Ph, W3 impl Ph) ∧ (∃ Ph, ¬ W3 impl Ph) := by
  constructor
  · exact ⟨impl.consciousHinge, fun _ => Iff.rfl⟩
  · refine ⟨fun _ => False, ?_⟩
    intro h
    exact (h s0).mp hconscious

def consistentCore : RawCore Unit Unit Unit where
  alpha := fun _ => Set.univ
  sigma := fun _ => Set.univ
  pi := fun _ => Set.univ
  rho := fun _ => Set.univ

theorem consistentCore_conv : ConvHolds consistentCore := by
  simp [ConvHolds, consistentCore]

def inconsistentCore : RawCore Unit Bool Unit where
  alpha := fun _ => Set.univ
  sigma := fun _ => ∅
  pi := fun _ => Set.univ
  rho := fun _ => Set.univ

theorem inconsistentCore_not_conv : ¬ ConvHolds inconsistentCore := by
  intro h
  have hmem : () ∈ inconsistentCore.sigma false :=
    (h.1 () false).mp (by simp [inconsistentCore])
  simpa [inconsistentCore] using hmem

def consistentImpl : FrozenImpl Unit Unit Unit Unit where
  core := consistentCore
  dc := fun _ => True
  nontrivial := True
  positiveValue := fun _ _ => True
  consciousHinge := fun _ => True
  hinge := fun _ => {()}
  step := fun _ _ => True

def inconsistentImpl : FrozenImpl Unit Bool Unit Unit where
  core := inconsistentCore
  dc := fun _ => True
  nontrivial := True
  positiveValue := fun _ _ => True
  consciousHinge := fun _ => True
  hinge := fun _ => {()}
  step := fun _ _ => True

theorem W4_indep : W4 consistentImpl ∧ ¬ W4 inconsistentImpl := by
  exact ⟨consistentCore_conv, inconsistentCore_not_conv⟩

theorem W6_true : W6 consistentImpl := by
  refine ⟨fun _ => (), ?_, ?_⟩
  · simp [consistentImpl]
  · intro n
    exact ⟨n, le_rfl, trivial⟩

def noViableImpl : FrozenImpl Unit Unit Unit Unit where
  core := consistentCore
  dc := fun _ => False
  nontrivial := True
  positiveValue := fun _ _ => False
  consciousHinge := fun _ => False
  hinge := fun _ => ∅
  step := fun _ _ => True

theorem W6_false : ¬ W6 noViableImpl := by
  rintro ⟨traj, _, recurrent⟩
  obtain ⟨m, _, hdc⟩ := recurrent 0
  exact hdc

theorem W6_indep : W6 consistentImpl ∧ ¬ W6 noViableImpl :=
  ⟨W6_true, W6_false⟩

end Wager
end ERIEC
