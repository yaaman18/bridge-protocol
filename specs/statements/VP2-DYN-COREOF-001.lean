import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_COREOF_001

universe u v w
variable {S : Type u} {W : Type v}

#check (ERIEC.Dynamics.coreOf :
  (W → Type w) → (S → W) → S → Type w)

end ERIECV2.Statement.VP2_DYN_COREOF_001
