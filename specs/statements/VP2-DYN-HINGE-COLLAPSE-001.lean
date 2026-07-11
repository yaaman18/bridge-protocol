import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_HINGE_COLLAPSE_001

universe u v w z

def Statement : Prop :=
  ∀ {M : Type u} {E : Type v} {C : Type w} {S : Type z}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : S → Set C) (epsilon : S → Set E) (s : S),
    kappa s = ∅ →
      ERIEC.Hinge.Act rhoRel sigmaRel kappa epsilon s = ∅ ∧
        ¬ (ERIEC.Hinge.Act rhoRel sigmaRel kappa epsilon s).Nonempty

example : Statement := ERIEC.Dynamics.hinge_collapse

end ERIECV2.Statement.VP2_DYN_HINGE_COLLAPSE_001
