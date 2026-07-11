import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_WEIGHTED_PURE_001

universe u v w

def Statement : Prop :=
  ∀ {M : Type u} {E : Type v} {R : Type w} [Mul R]
    {tensor₁ tensor₂ : M → E → R} {value₁ value₂ : E → R},
    tensor₁ = tensor₂ → value₁ = value₂ →
      ERIEC.Value.weighted_O tensor₁ value₁ =
        ERIEC.Value.weighted_O tensor₂ value₂

example : Statement := by
  intro M E R inst tensor₁ tensor₂ value₁ value₂ hTensor hValue
  exact ERIEC.Value.weighted_O_endogenous hTensor hValue

end ERIECV2.Statement.VP2_VAL_WEIGHTED_PURE_001
