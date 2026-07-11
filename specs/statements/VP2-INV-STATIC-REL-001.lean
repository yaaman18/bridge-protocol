import ERIEC.Invariance.Static

open ERIEC.Invariance

namespace ERIECV2.Statement.VP2_INV_STATIC_REL_001

#check (ERIEC.Invariance.static_rel_bisim :
  ∀ {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F'),
    (∀ a, image h.hE (F.alphaRel a) = F'.alphaRel (h.hA a)) ∧
    (∀ e, image h.hA (F.sigmaRel e) = F'.sigmaRel (h.hE e)) ∧
    (∀ a, image h.hC (F.piRel a) = F'.piRel (h.hA a)) ∧
    (∀ c, image h.hA (F.rhoRel c) = F'.rhoRel (h.hC c)))

end ERIECV2.Statement.VP2_INV_STATIC_REL_001
