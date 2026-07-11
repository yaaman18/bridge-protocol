import ERIEC.Invariance.Dynamic

open ERIEC.Invariance ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_INV_INS_001

#check (ERIEC.Invariance.INS_invariant :
  ∀ {A E C S A' E' C' S' W Ω : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    {step : S → S → Prop} {step' : S' → S' → Prop}
    {observe : S → Ω} {observe' : S' → Ω}
    (h : KIso F F')
    (hdyn : DynamicIso h step step' observe observe'),
    INS observe (K step {s | F.DCAt s}) ↔
      INS observe' (K step' {s | F'.DCAt s}))

end ERIECV2.Statement.VP2_INV_INS_001
