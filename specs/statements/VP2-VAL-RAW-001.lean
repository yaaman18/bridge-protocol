import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_RAW_001

universe u v
variable {E : Type u} {C : Type v} [DecidableEq C]

#check (ERIEC.Value.raw_V :
  Finset C → (E → Finset C) → E → Nat)

end ERIECV2.Statement.VP2_VAL_RAW_001
