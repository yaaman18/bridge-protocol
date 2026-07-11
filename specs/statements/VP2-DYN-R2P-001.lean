import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_R2P_001

universe u v
variable {C : Type u} {W : Type v} [LinearOrder W] [OrderTop W]

#check (ERIEC.Dynamics.R2Prime : (W → Set C → W) → Prop)

end ERIECV2.Statement.VP2_DYN_R2P_001
