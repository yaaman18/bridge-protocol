import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_ENDOGENOUS_001

universe u v w

def Statement : Prop :=
  ∀ {M : Type u} {E : Type v} {C : Type w} [DecidableEq C] [Fintype C]
    {sigma₁ sigma₂ : E → Set M}
    {pi₁ pi₂ : M → Set C} {rho₁ rho₂ : C → Set M},
    sigma₁ = sigma₂ → pi₁ = pi₂ → rho₁ = rho₂ →
      ERIEC.Value.relationalNormalizedV sigma₁ pi₁ rho₁ =
        ERIEC.Value.relationalNormalizedV sigma₂ pi₂ rho₂

example : Statement := by
  intro M E C dec fin sigma₁ sigma₂ pi₁ pi₂ rho₁ rho₂ hSigma hPi hRho
  exact ERIEC.Value.V_endogenous hSigma hPi hRho

end ERIECV2.Statement.VP2_VAL_ENDOGENOUS_001
