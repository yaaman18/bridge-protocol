import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_PATH_ITERATE_001

universe u v w z

def Statement : Prop :=
  ∀ {C : Type u} {E : Type v} {W : Type w} {S : Type z}
    (frame : ERIEC.Dynamics.DynFrame C E W S)
    {s t : S} {n : Nat},
    ERIEC.Dynamics.InternalPath frame.stepInt s n t →
      frame.conf t = (frame.update^[n]) (frame.conf s)

example : Statement := by
  intro C E W S frame s t n path
  exact ERIEC.Dynamics.path_conf_iterate frame path

end ERIECV2.Statement.VP2_DYN_PATH_ITERATE_001
