import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_COUNTERMODEL_001

def Statement : Prop :=
  ∃ model : ERIEC.Value.StableModel Bool Unit Unit Unit Unit,
    ¬ ERIEC.Value.StableTarget model

example : Statement := ERIEC.Value.countermodel

end ERIECV2.Statement.VP2_VAL_COUNTERMODEL_001
