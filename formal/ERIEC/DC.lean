import ERIEC.Hinge
import ERIEC.Grading

namespace ERIEC

structure DC (M E C S : Type*) where
  alphaRel : M -> Set E
  sigmaRel : E -> Set M
  piRel : M -> Set C
  rhoRel : C -> Set M
  kappa : S -> Set C
  epsilon : S -> Set E
  boundary : Set C
  s : S
  hSelf : kappa s ⊆ Closure.Phi piRel rhoRel (kappa s)
  hSMC : epsilon s ⊆ Hinge.T_prime alphaRel sigmaRel (epsilon s)
  hAct : (Hinge.Act rhoRel sigmaRel kappa epsilon s).Nonempty
  hBound : (kappa s ∩ boundary).Nonempty

namespace DC

theorem act_nonempty {M E C S : Type*} (dc : DC M E C S) :
    (Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty :=
  dc.hAct

theorem not_dc_of_act_empty {M E C S : Type*} (dc : DC M E C S)
    (h : ¬ (Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty) :
    False :=
  h dc.hAct

theorem hinge_requires_both {M E C S : Type*}
    (rhoRel : C -> Set M) (sigmaRel : E -> Set M)
    (kappa : S -> Set C) (s : S) :
    Hinge.Act rhoRel sigmaRel kappa (fun _ => ∅) s = ∅ :=
  Hinge.hinge_requires_both rhoRel sigmaRel kappa s

theorem empty_propagation_left {M E C S : Type*}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (epsilon : S → Set E) (s : S) :
    Hinge.Act rhoRel sigmaRel (fun _ => ∅) epsilon s = ∅ := by
  ext m
  simp [Hinge.Act, Closure.rho_star]

theorem empty_propagation_right {M E C S : Type*}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : S → Set C) (s : S) :
    Hinge.Act rhoRel sigmaRel kappa (fun _ => ∅) s = ∅ :=
  Hinge.hinge_requires_both rhoRel sigmaRel kappa s

/-- A nonempty certified post-fixed configuration cannot lie strictly above
the Sig-2 threshold. -/
theorem crit_bound {W C : Type*} [LT W]
    (family : Grading.RankedClosure W C) (threshold rank : W)
    (hsig2 : Grading.sig2 family threshold)
    (K : Set C) (hne : K.Nonempty) (hpost : K ⊆ family.op rank K) :
    ¬ threshold < rank := by
  intro habove
  exact hsig2 rank habove K hne hpost

end DC

end ERIEC
