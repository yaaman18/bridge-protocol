import ERIEC.RefModel

/-!
VP2-M1-FULL-001b freezes the Tier-2 bridge-shaped connection for M-1 full.

Primary source:
  category/三層構造の圏論的定式化_v5_1.md §0.3 and §13
  docs/７月７日追加課題.md, Q5/Q6 Tier split
  source revision: 1798d8e4758e294a0b40eeca139853e85681c404

Scope:
  Tier-2 shape only. The witness extends VP2-M1-FULL-001a with existing
  nontrivial World/Value witnesses and the certified §13.2 nondegenerate
  reference obligations. It is a DCWorldBridge-style consistency witness and
  does not assert an unconditional DC ↔ World equivalence or a phenomenal
  claim.
-/

namespace ERIECV2.Statement.VP2_M1_FULL_001b

#check ERIEC.RefModel.LargeThreeLayerReferenceWitness

#check (ERIEC.RefModel.arbitrarily_large_three_layer_reference_model :
  ∀ k : ℕ, 2 ≤ k →
    Nonempty (ERIEC.RefModel.LargeThreeLayerReferenceWitness k))

#print axioms ERIEC.RefModel.arbitrarily_large_three_layer_reference_model

end ERIECV2.Statement.VP2_M1_FULL_001b
