import ERIEC.RefModel

/-!
VP2-M1-FULL-001a freezes the Tier-1 discrete/dynamic part of M-1 full.

Primary source:
  category/三層構造の圏論的定式化_v5_1.md §0.3 and §13
  source revision: 1798d8e4758e294a0b40eeca139853e85681c404

This statement uses the current v5.1 reading:
  AX_core = AX_stable ∪ AX_dyn
and does not include the withdrawn layer-coherence condition 6.3 from older
preparation notes.

Scope:
  Tier-1 only. The witness must include carrier size at least k, true
  multivalued alphaRel, a DC state, nonempty hinge/action, R2Prime, E5, and
  internal totality. Nontrivial World/Value witnesses and the full §13.2
  three-layer connection are reserved for VP2-M1-FULL-001b.
-/

namespace ERIECV2.Statement.VP2_M1_FULL_001a

#check ERIEC.RefModel.LargeStableReferenceWitness
#check ERIEC.RefModel.LargeDynamicReferenceWitness
#check ERIEC.RefModel.LargeAXCoreReferenceWitness

#check (ERIEC.RefModel.arbitrarily_large_ax_core_discrete_model :
  ∀ k : ℕ, 2 ≤ k →
    Nonempty (ERIEC.RefModel.LargeAXCoreReferenceWitness k))

#print axioms ERIEC.RefModel.arbitrarily_large_ax_core_discrete_model

end ERIECV2.Statement.VP2_M1_FULL_001a
