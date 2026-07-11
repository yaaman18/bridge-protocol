import ERIEC.Invariance.Static

open ERIEC.Invariance

namespace ERIECV2.Statement.VP2_INV_STATIC_CLOSURE_001

#check (ERIEC.Invariance.static_closure_bisim :
  ∀ {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F'),
    (∀ Y, image h.hC (ERIEC.Closure.Phi F.piRel F.rhoRel Y) =
      ERIEC.Closure.Phi F'.piRel F'.rhoRel (image h.hC Y)) ∧
    image h.hC (ERIEC.Closure.nu (ERIEC.Closure.Phi F.piRel F.rhoRel)) =
      ERIEC.Closure.nu (ERIEC.Closure.Phi F'.piRel F'.rhoRel) ∧
    (∀ K X, image h.hA
      (ERIEC.Closure.rho_star F.rhoRel K ∩ ERIEC.Adj.sigma_star F.sigmaRel X) =
      ERIEC.Closure.rho_star F'.rhoRel (image h.hC K) ∩
        ERIEC.Adj.sigma_star F'.sigmaRel (image h.hE X)))

end ERIECV2.Statement.VP2_INV_STATIC_CLOSURE_001
