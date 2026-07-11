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

end ERIECV2.Statement.VP2_GEN_LINEAGE_OPEN_001
