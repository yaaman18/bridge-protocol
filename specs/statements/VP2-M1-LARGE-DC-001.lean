import ERIEC.RefModel

namespace ERIECV2.Statement.VP2_M1_LARGE_DC_001

#check ERIEC.RefModel.largeFiniteDC
#check ERIEC.RefModel.LargeNondegenerateWitness
#check (ERIEC.RefModel.arbitrarily_large_nondegenerate_dc :
  ∀ k : ℕ, 2 ≤ k → Nonempty (ERIEC.RefModel.LargeNondegenerateWitness k))
#print axioms ERIEC.RefModel.arbitrarily_large_nondegenerate_dc

end ERIECV2.Statement.VP2_M1_LARGE_DC_001
