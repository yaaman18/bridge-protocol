import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_DOWNV_001

universe u
variable {S : Type u}

#check (ERIEC.Dynamics.downV :
  (S → S → Prop) → Set S → Set S)

end ERIECV2.Statement.VP2_DYN_DOWNV_001
