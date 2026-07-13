import ERIEC.Generation

namespace ERIECV2.Statement.VP2_GEN_RICHNESS_INHERITS_001

#check (ERIEC.Generation.richness_inherits_generational :
  ∀ {M E C S M' E' C' S'}
    {parent : ERIEC.DC M E C S} {child : ERIEC.DC M' E' C' S'},
    ERIEC.Generation.ProliferationMorphism parent child →
      ERIEC.Generation.phi_rich parent ≤ ERIEC.Generation.phi_rich child)
#check ERIEC.Generation.branch_transport_inherits_nu
#print axioms ERIEC.Generation.richness_inherits_generational

end ERIECV2.Statement.VP2_GEN_RICHNESS_INHERITS_001
