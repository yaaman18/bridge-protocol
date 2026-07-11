import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_REACHABLE_001

universe u
variable {S : Type u}

#check (ERIEC.Dynamics.Reachable :
  (S → S → Prop) → S → S → Prop)

end ERIECV2.Statement.VP2_DYN_REACHABLE_001
