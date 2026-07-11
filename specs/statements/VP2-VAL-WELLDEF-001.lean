import ERIEC.Value

namespace ERIECV2.Statement.VP2_VAL_WELLDEF_001

universe u v

def Statement : Prop :=
  ∀ {M : Type u} {C : Type v}
    (piRel : M → Set C) (rhoRel : C → Set M)
    (kappa boundary : Set C),
    kappa ⊆ ERIEC.Closure.Phi piRel rhoRel kappa →
      (kappa ∩ boundary).Nonempty →
        (ERIEC.Closure.nu (ERIEC.Closure.Phi piRel rhoRel)).Nonempty

example : Statement := by
  intro M C piRel rhoRel kappa boundary h1 h4
  exact ERIEC.Value.V_welldef piRel rhoRel kappa boundary h1 h4

end ERIECV2.Statement.VP2_VAL_WELLDEF_001
