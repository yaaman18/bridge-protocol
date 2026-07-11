import ERIEC.Hinge

namespace ERIEC

namespace Collapse


/-- Empty intrinsic configuration forces the hinge to collapse. -/
theorem hingeCollapse {M E C S : Type*}
    (rhoRel : C -> Set M) (sigmaRel : E -> Set M)
    (kappa : S -> Set C) (epsilon : S -> Set E) (s : S)
    (hKappa : kappa s = ∅) :
    Hinge.Act rhoRel sigmaRel kappa epsilon s = ∅ := by
  unfold Hinge.Act
  rw [hKappa]
  ext m
  constructor
  · intro hm
    rcases Set.mem_iUnion.mp hm.1 with ⟨c, hc⟩
    rcases Set.mem_iUnion.mp hc with ⟨hEmpty, _⟩
    exact hEmpty
  · intro hm
    exact hm.elim

end Collapse

end ERIEC
