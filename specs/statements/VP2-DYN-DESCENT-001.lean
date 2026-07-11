import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_DESCENT_001

universe u v w

def Statement : Prop :=
  ∀ {C : Type u} {E : Type v} {W : Type w}
    (phi : W → Set C → Set C) (theta : W → Set E → Set E)
    (drift : W → Set C → W) (c : ERIEC.Dynamics.Conf C E W),
    ¬ c.kappa ⊆ phi c.rank c.kappa →
      (ERIEC.Dynamics.upd phi theta drift c).kappa ⊂ c.kappa

example : Statement := by
  intro C E W phi theta drift c h
  exact ERIEC.Dynamics.kappa_descends_strict phi theta drift c h

end ERIECV2.Statement.VP2_DYN_DESCENT_001
