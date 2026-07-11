import ERIEC.Wager
import ERIEC.RefModel

namespace ERIECV2.Statement.VP2_WAGER_W5_FAMILY_001

#check ERIEC.Wager.richImpl
#check ERIEC.Wager.richImpl_W5
#check ERIEC.Wager.poorImpl_not_W5
#check ERIEC.RefModel.parameterizedRichDC
#check ERIEC.RefModel.parameterizedRichDC_act_eq_univ
#check ERIEC.RefModel.richImpl_hinge_card
#check ERIEC.RefModel.richImpl_realized_by_DC
#check ERIEC.RefModel.ParameterizedRichReferenceWitness
#check ERIEC.RefModel.parameterized_rich_reference_model
#check (ERIEC.Wager.W5_indep_all :
  ∀ k0 : ℕ, 2 ≤ k0 →
    ERIEC.Wager.W5 (ERIEC.Wager.richImpl k0) k0 ∧
      ¬ ERIEC.Wager.W5 ERIEC.Wager.poorImpl k0)
#print axioms ERIEC.Wager.W5_indep_all
#print axioms ERIEC.RefModel.richImpl_realized_by_DC
#print axioms ERIEC.RefModel.parameterized_rich_reference_model

end ERIECV2.Statement.VP2_WAGER_W5_FAMILY_001
