import ERIEC.WorldDC

namespace ERIECV2.Statement.VP2_WDC_FORWARD_CE_001

def Statement : Prop :=
  ∃ (dc : ERIEC.DC Unit Unit Unit Unit)
    (L : EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1)),
    ¬ ERIEC.World.WldNontrivial L

example : Statement := ERIEC.WorldDC.no_forward_unconditional

end ERIECV2.Statement.VP2_WDC_FORWARD_CE_001
