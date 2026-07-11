import ERIEC.World

namespace ERIECV2.Statement.VP2_WLD_CHI_NONTRIV_001

def Statement : Prop :=
  ∀ {m : Nat} [NeZero m]
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)),
    L.toLinearMap.IsSymmetric → ∀ eta : ℝ,
      ERIEC.World.chi L ≤ eta → ERIEC.World.Wld_band L eta ≠ ⊥

example : Statement := ERIEC.World.band_nontrivial_of_chi_le

end ERIECV2.Statement.VP2_WLD_CHI_NONTRIV_001
