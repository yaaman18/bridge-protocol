import ERIEC.Generation

namespace ERIECV2.Statement.VP2_GEN_LINEAGE_OPEN_001

#check (ERIEC.Generation.lineage_stays_open :
  {Q : Type} → [PartialOrder Q] →
    (sem : ERIEC.OpenEvolution.SemanticEquivalence) →
    (L : ERIEC.OpenEvolution.Lineage ERIEC.Generation.ProliferationEvent) →
    (q : ERIEC.OpenEvolution.OpenSystem → Q) →
    (∀ {left right}, sem.rel left right → q left = q right) →
    ERIEC.OpenEvolution.Lineage.Cofinal q L →
    ERIEC.OpenEvolution.Lineage.FreshSem sem L)

#print axioms ERIEC.Generation.lineage_stays_open

#check ERIEC.Generation.PhiRich
#check ERIEC.Generation.lineage_stays_open_phi_rich
#print axioms ERIEC.Generation.lineage_stays_open_phi_rich

end ERIECV2.Statement.VP2_GEN_LINEAGE_OPEN_001
