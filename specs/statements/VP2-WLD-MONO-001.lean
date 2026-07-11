import ERIEC.World

namespace ERIECV2.Statement.VP2_WLD_MONO_001

def Statement : Prop :=
  ∀ {m : Nat}
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    {eta eta' : ℝ},
    eta ≤ eta' → ERIEC.World.Wld_band L eta ≤ ERIEC.World.Wld_band L eta'

example : Statement := ERIEC.World.band_mono

end ERIECV2.Statement.VP2_WLD_MONO_001
