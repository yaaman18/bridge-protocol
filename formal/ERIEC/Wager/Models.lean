import ERIEC.Wager.Preservation

namespace ERIEC
namespace Wager

/-!
Named frozen-model witnesses for §14.

These names expose the finite witness roles used by the current Lean
abstraction. They intentionally do not add target-layer axioms or phenomenal
claims; they package the already-certified positive/negative Wager witnesses
under the names used by the frozen-document work plan.
-/

abbrev KBad : RawCore Unit Bool Unit := inconsistentCore

abbrev M0 : FrozenImpl Unit Unit Unit Unit := consistentImpl

abbrev KPlus : RawCore Unit Unit Unit := consistentCore

abbrev MPlus : FrozenImpl Unit Unit Unit Unit := noViableImpl

abbrev MCyc : FrozenImpl Unit Unit Unit Unit := consistentImpl

theorem KBad_not_conv : ¬ ConvHolds KBad := by
  simpa [KBad] using inconsistentCore_not_conv

theorem KPlus_conv : ConvHolds KPlus := by
  simpa [KPlus] using consistentCore_conv

theorem M0_w6 : W6 M0 := by
  simpa [M0] using W6_true

theorem MPlus_not_w6 : ¬ W6 MPlus := by
  simpa [MPlus] using W6_false

theorem MCyc_w6 : W6 MCyc := by
  simpa [MCyc] using W6_true

theorem named_frozen_models_boundary :
    ¬ ConvHolds KBad ∧ ConvHolds KPlus ∧ W6 M0 ∧ ¬ W6 MPlus ∧ W6 MCyc := by
  exact ⟨KBad_not_conv, KPlus_conv, M0_w6, MPlus_not_w6, MCyc_w6⟩

def CycleAt {S : Type*} (step : S → S → Prop) (s : S) : Prop :=
  step s s

theorem W6_of_dc_cycle {A E C S : Type*} (impl : FrozenImpl A E C S)
    {s : S} (hdc : impl.dc s) (hcycle : CycleAt impl.step s) : W6 impl := by
  refine ⟨fun _ => s, ?_, ?_⟩
  · intro n
    exact hcycle
  · intro n
    exact ⟨n, le_rfl, hdc⟩

structure FrozenModelCheck (A E C S : Type*) where
  impl : FrozenImpl A E C S
  k0 : ℕ
  w4 : W4 impl
  w5 : W5 impl k0
  w6 : W6 impl

theorem frozen_model_checker_soundness {A E C S : Type*}
    (check : FrozenModelCheck A E C S) :
    W4 check.impl ∧ W5 check.impl check.k0 ∧ W6 check.impl :=
  ⟨check.w4, check.w5, check.w6⟩

structure FrozenInterpretiveCheck (A E C S : Type*) where
  impl : FrozenImpl A E C S
  Ph : S → Prop
  Mat : S → E → Prop
  w1 : W1 impl Ph
  w2 : W2 impl Mat
  w3 : W3 impl Ph

theorem frozen_interpretive_checker_soundness {A E C S : Type*}
    (check : FrozenInterpretiveCheck A E C S) :
    W1 check.impl check.Ph ∧ W2 check.impl check.Mat ∧ W3 check.impl check.Ph :=
  ⟨check.w1, check.w2, check.w3⟩

structure FrozenFullModelCheck (A E C S : Type*) where
  impl : FrozenImpl A E C S
  Ph : S → Prop
  Mat : S → E → Prop
  k0 : ℕ
  w1 : W1 impl Ph
  w2 : W2 impl Mat
  w3 : W3 impl Ph
  w4 : W4 impl
  w5 : W5 impl k0
  w6 : W6 impl

theorem frozen_full_model_checker_soundness {A E C S : Type*}
    (check : FrozenFullModelCheck A E C S) :
    W1 check.impl check.Ph ∧ W2 check.impl check.Mat ∧ W3 check.impl check.Ph ∧
      W4 check.impl ∧ W5 check.impl check.k0 ∧ W6 check.impl :=
  ⟨check.w1, check.w2, check.w3, check.w4, check.w5, check.w6⟩

end Wager
end ERIEC
