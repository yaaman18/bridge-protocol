import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_BDPAIR_001

universe u
variable {S : Type u}

#check (ERIEC.Dynamics.BdPair :
  (S → S → Prop) → Set S → Set (S × S))

end ERIECV2.Statement.VP2_DYN_BDPAIR_001
