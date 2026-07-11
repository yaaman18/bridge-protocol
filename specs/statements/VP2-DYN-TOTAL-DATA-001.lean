import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_TOTAL_DATA_001

universe u
variable {S : Type u}

#check (ERIEC.Dynamics.TotalNext : (S → S → Prop) → Type u)

def Statement (S : Type u) : Prop :=
  ∀ (stepInt : S → S → Prop),
    ERIEC.Dynamics.TotalNext stepInt → ERIEC.Dynamics.InternallyTotal stepInt

example : Statement S := by
  intro stepInt total
  exact total.internallyTotal

end ERIECV2.Statement.VP2_DYN_TOTAL_DATA_001
