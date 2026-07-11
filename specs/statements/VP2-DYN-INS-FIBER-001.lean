import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_INS_FIBER_001

universe u v

def Statement : Prop :=
  ∀ {S : Type u} {Ω : Type v} (observe : S → Ω) (region : Set S),
    ERIEC.Dynamics.INS observe region ↔
      ∃ inside, inside ∈ region ∧
        ∃ outside, outside ∉ region ∧ observe inside = observe outside

example : Statement := by
  intro S Ω observe region
  exact ERIEC.Dynamics.INS_iff_fiber observe region

end ERIECV2.Statement.VP2_DYN_INS_FIBER_001
