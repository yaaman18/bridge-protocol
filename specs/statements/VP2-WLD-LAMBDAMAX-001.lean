import ERIEC.World

namespace ERIECV2.Statement.VP2_WLD_LAMBDAMAX_001

def Statement : Prop :=
  ∀ {m e : Nat} [NeZero m]
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)),
    ERIEC.World.lambdaMax (ERIEC.World.worldLoop sigma a) =
      ‖ERIEC.Sens.T_w sigma a‖ ^ 2

example : Statement := ERIEC.World.lambdaMax_eq_normSq_T

end ERIECV2.Statement.VP2_WLD_LAMBDAMAX_001
