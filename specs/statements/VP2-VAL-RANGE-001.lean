import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_RANGE_001

universe u v

def Statement : Prop :=
  ∀ {E : Type u} {C : Type v} [DecidableEq C]
    (nuPhi : Finset C) (contribution : E → Finset C) (e : E),
    nuPhi.Nonempty →
      0 ≤ ERIEC.Value.normalized_V nuPhi contribution e ∧
        ERIEC.Value.normalized_V nuPhi contribution e ≤ 1

example : Statement := by
  intro E C inst nuPhi contribution e hNu
  exact ERIEC.Value.V_range nuPhi contribution e hNu

end ERIECV2.Statement.VP2_VAL_RANGE_001
