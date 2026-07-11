import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_TOTAL_ORBIT_001

universe u v w z

def Statement : Prop :=
  ∀ {C : Type u} {E : Type v} {W : Type w} {S : Type z}
    (frame : ERIEC.Dynamics.DynFrame C E W S)
    (total : ERIEC.Dynamics.TotalNext frame.stepInt) (s : S),
    ERIEC.Dynamics.FiniteCollapse frame.update (frame.conf s) →
      (∀ n, frame.stepInt ((total.next^[n]) s) ((total.next^[n + 1]) s)) ∧
        ∃ N, ∀ k, N ≤ k → frame.kappa ((total.next^[k]) s) = ∅

example : Statement := by
  intro C E W S frame total s hCollapse
  exact ERIEC.Dynamics.total_orbit_collapse frame total s hCollapse

end ERIECV2.Statement.VP2_DYN_TOTAL_ORBIT_001
