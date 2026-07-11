import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_CONF_001

universe u v w
variable {C : Type u} {E : Type v} {W : Type w}

#check (ERIEC.Dynamics.Conf.mk :
  Set C → Set E → W → ERIEC.Dynamics.Conf C E W)

end ERIECV2.Statement.VP2_DYN_CONF_001
