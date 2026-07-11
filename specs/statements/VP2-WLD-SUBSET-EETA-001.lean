import ERIEC.World

namespace ERIECV2.Statement.VP2_WLD_SUBSET_EETA_001

def Statement : Prop :=
  ∀ {m : Nat}
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)),
    L.toLinearMap.IsSymmetric → ∀ eta : ℝ,
      (ERIEC.World.Wld_band L eta : Set (EuclideanSpace ℝ (Fin m))) ⊆
        ERIEC.World.Eeta L eta

example : Statement := ERIEC.World.band_subset_Eeta

end ERIECV2.Statement.VP2_WLD_SUBSET_EETA_001
