import ERIEC.BridgeFunctor

open ERIEC.BridgeFunctor

namespace ERIECV2.Statement.VP2_A1_ALPHA_ONLY_CE_001

#check (ERIEC.BridgeFunctor.no_alphaOnly_hinge_classifier :
  ¬ ∃ classify : (Unit → Set Unit) → Prop,
    AlphaOnlyClassifiesHinge (C := Unit) classify)

#print axioms ERIEC.BridgeFunctor.no_alphaOnly_hinge_classifier

end ERIECV2.Statement.VP2_A1_ALPHA_ONLY_CE_001
