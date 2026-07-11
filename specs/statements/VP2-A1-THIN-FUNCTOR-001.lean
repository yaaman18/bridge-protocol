import ERIEC.BridgeFunctor

open ERIEC.BridgeFunctor

namespace ERIECV2.Statement.VP2_A1_THIN_FUNCTOR_001

#check ERIEC.BridgeFunctor.hingeClassifierFunctor

#check (ERIEC.BridgeFunctor.hingeClassifierFunctor_nontrivial_iff :
  ∀ (X : CompleteHingeData),
    ERIEC.World.WldNontrivial (hingeClassifierFunctor.obj X).loop ↔ X.holds)

#print axioms ERIEC.BridgeFunctor.hingeClassifierFunctor_nontrivial_iff

end ERIECV2.Statement.VP2_A1_THIN_FUNCTOR_001
