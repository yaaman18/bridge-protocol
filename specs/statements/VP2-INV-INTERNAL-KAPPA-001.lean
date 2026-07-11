import ERIEC.Invariance.Static

open ERIEC.Invariance

namespace ERIECV2.Statement.VP2_INV_INTERNAL_KAPPA_001

#check (ERIEC.Invariance.internal_bisim_kappa :
  ∀ {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (_w : W) (K : Set C),
    image h.hC (K ∩ ERIEC.Closure.Phi F.piRel F.rhoRel K) =
      image h.hC K ∩ ERIEC.Closure.Phi F'.piRel F'.rhoRel (image h.hC K))

end ERIECV2.Statement.VP2_INV_INTERNAL_KAPPA_001
