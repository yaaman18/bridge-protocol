import ERIEC.World

namespace ERIECV2.Statement.VP2_WLD_CHI_001

#check (ERIEC.World.chi :
  (EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1)) → ℝ)

example (L : EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1)) :
    ERIEC.World.chi L = |1 - ERIEC.World.lambdaMax L| := rfl

end ERIECV2.Statement.VP2_WLD_CHI_001
