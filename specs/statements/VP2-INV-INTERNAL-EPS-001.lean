import ERIEC.Invariance.Static

open ERIEC.Invariance

namespace ERIECV2.Statement.VP2_INV_INTERNAL_EPS_001

#check (ERIEC.Invariance.internal_bisim_epsilon :
  ∀ {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (X : Set E),
    image h.hE (X ∩ ERIEC.Hinge.T_prime F.alphaRel F.sigmaRel X) =
      image h.hE X ∩
        ERIEC.Hinge.T_prime F'.alphaRel F'.sigmaRel (image h.hE X))

end ERIECV2.Statement.VP2_INV_INTERNAL_EPS_001
