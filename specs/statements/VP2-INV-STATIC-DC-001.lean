import ERIEC.Invariance.Static

open ERIEC.Invariance

namespace ERIECV2.Statement.VP2_INV_STATIC_DC_001

#check (ERIEC.Invariance.static_DC_bisim :
  ∀ {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (s : S), F.DCAt s ↔ F'.DCAt (h.hS s))

end ERIECV2.Statement.VP2_INV_STATIC_DC_001
