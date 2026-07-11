import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_NORMALIZED_001

universe u v
variable {E : Type u} {C : Type v} [DecidableEq C]

#check (ERIEC.Value.normalized_V :
  Finset C → (E → Finset C) → E → ℚ)

end ERIECV2.Statement.VP2_VAL_NORMALIZED_001
