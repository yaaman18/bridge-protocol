import ERIEC.Adjunction
import ERIEC.Closure

namespace ERIEC

namespace Hinge

def T_prime {M E : Type*} (alphaRel : M -> Set E) (sigmaRel : E -> Set M)
    (X : Set E) : Set E :=
  Adj.alpha_star alphaRel (Adj.sigma_star sigmaRel X)

def Act {M E C S : Type*} (rhoRel : C -> Set M) (sigmaRel : E -> Set M)
    (kappa : S -> Set C) (epsilon : S -> Set E) (s : S) : Set M :=
  Closure.rho_star rhoRel (kappa s) ∩ Adj.sigma_star sigmaRel (epsilon s)

theorem act_def {M E C S : Type*} (rhoRel : C -> Set M) (sigmaRel : E -> Set M)
    (kappa : S -> Set C) (epsilon : S -> Set E) (s : S) :
    Act rhoRel sigmaRel kappa epsilon s =
      Closure.rho_star rhoRel (kappa s) ∩ Adj.sigma_star sigmaRel (epsilon s) := rfl

theorem act_nonempty_necessary {M E C S : Type*}
    {rhoRel : C -> Set M} {sigmaRel : E -> Set M}
    {kappa : S -> Set C} {epsilon : S -> Set E} {s : S}
    (h : Act rhoRel sigmaRel kappa epsilon s = ∅) :
    Closure.rho_star rhoRel (kappa s) ∩ Adj.sigma_star sigmaRel (epsilon s) = ∅ :=
  h

theorem sigma_star_empty {M E : Type*} (sigmaRel : E -> Set M) :
    Adj.sigma_star sigmaRel ∅ = ∅ := by
  ext m
  simp [Adj.sigma_star]

theorem hinge_requires_both {M E C S : Type*}
    (rhoRel : C -> Set M) (sigmaRel : E -> Set M)
    (kappa : S -> Set C) (s : S) :
    Act rhoRel sigmaRel kappa (fun _ => ∅) s = ∅ := by
  simp [Act, sigma_star_empty]

end Hinge

end ERIEC
