import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_TRANSPORT_001

universe u v w
variable {S : Type u} {W : Type v}

#check (ERIEC.Dynamics.Transport :
  (S → S → Prop) → (W → Type w) → (S → W) → S → S → Prop)

end ERIECV2.Statement.VP2_DYN_TRANSPORT_001
