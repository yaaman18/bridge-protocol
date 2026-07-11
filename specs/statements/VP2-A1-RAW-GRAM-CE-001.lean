import ERIEC.BridgeFunctor

open ERIEC.BridgeFunctor

namespace ERIECV2.Statement.VP2_A1_RAW_GRAM_CE_001

#check (ERIEC.BridgeFunctor.raw_gram_bridge_counterexample :
  ∃ (alphaRel : Unit → Set Bool) (rhoRel : Unit → Set Unit)
    (sigmaRel : Bool → Set Unit) (kappa : Set Unit) (epsilon : Set Bool),
    HingeWitness rhoRel sigmaRel kappa epsilon ∧
      ¬ MatrixFixedNontrivial (relationGram alphaRel))

#print axioms ERIEC.BridgeFunctor.raw_gram_bridge_counterexample

end ERIECV2.Statement.VP2_A1_RAW_GRAM_CE_001
