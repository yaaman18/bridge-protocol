import ERIEC.World

namespace ERIECV2.Statement.VP2_WLD_INVARIANT_001

def Statement : Prop :=
  ∀ {m : Nat}
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    (eta : ℝ) {x : EuclideanSpace ℝ (Fin m)},
    x ∈ ERIEC.World.Wld_band L eta →
      L x ∈ ERIEC.World.Wld_band L eta

example : Statement := ERIEC.World.band_invariant

end ERIECV2.Statement.VP2_WLD_INVARIANT_001
