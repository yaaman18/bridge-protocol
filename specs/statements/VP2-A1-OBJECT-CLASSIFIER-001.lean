import ERIEC.BridgeFunctor

open ERIEC.BridgeFunctor

namespace ERIECV2.Statement.VP2_A1_OBJECT_CLASSIFIER_001

#check (ERIEC.BridgeFunctor.hingeClassifyingLoop_nontrivial_iff :
  ∀ {M E C : Type*}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : Set C) (epsilon : Set E),
    ERIEC.World.WldNontrivial
        (hingeClassifyingLoop rhoRel sigmaRel kappa epsilon) ↔
      HingeWitness rhoRel sigmaRel kappa epsilon)

#print axioms ERIEC.BridgeFunctor.hingeClassifyingLoop_nontrivial_iff

end ERIECV2.Statement.VP2_A1_OBJECT_CLASSIFIER_001
