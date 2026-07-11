import ERIEC.World

namespace ERIECV2.Statement.VP2_WLD_ZERO_FIX_001

def Statement : Prop :=
  ∀ {m : Nat}
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)),
    ERIEC.World.Wld_band L 0 = ERIEC.World.Fix L

example : Statement := ERIEC.World.band_zero_eq_fix

end ERIECV2.Statement.VP2_WLD_ZERO_FIX_001
