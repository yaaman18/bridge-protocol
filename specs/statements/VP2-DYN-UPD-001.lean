import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_UPD_001

universe u v w
variable {C : Type u} {E : Type v} {W : Type w}

#check (ERIEC.Dynamics.upd :
  (W → Set C → Set C) →
  (W → Set E → Set E) →
  (W → Set C → W) →
  ERIEC.Dynamics.Conf C E W →
  ERIEC.Dynamics.Conf C E W)

end ERIECV2.Statement.VP2_DYN_UPD_001
