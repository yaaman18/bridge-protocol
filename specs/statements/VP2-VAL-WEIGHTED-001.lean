import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_WEIGHTED_001

universe u v w
variable {M : Type u} {E : Type v} {R : Type w} [Mul R]

#check (ERIEC.Value.weighted_O :
  (M → E → R) → (E → R) → M → E → R)

example (tensor : M → E → R) (value : E → R) (m : M) (e : E) :
    ERIEC.Value.weighted_O tensor value m e = tensor m e * value e := rfl

end ERIECV2.Statement.VP2_VAL_WEIGHTED_001
