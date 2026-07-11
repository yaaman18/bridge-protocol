import ERIEC.WorldDC

namespace ERIECV2.Statement.VP2_WDC_BACKWARD_CE_001

def Statement : Prop :=
  ∃ L : EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1),
    ERIEC.World.WldNontrivial L ∧
      ¬ ∃ dc : ERIEC.DC Unit Unit Unit Unit, dc.boundary = ∅

example : Statement := ERIEC.WorldDC.no_backward_unconditional

end ERIECV2.Statement.VP2_WDC_BACKWARD_CE_001
