import ERIEC.InterfaceLinearization

open ERIEC.InterfaceLinearization

namespace ERIECV2.Statement.VP2_I1_REL_LIN_001

#check (ERIEC.InterfaceLinearization.convSystem_linearization_eq_adjoint :
  ∀ {M E : Type*}
    [Fintype M] [DecidableEq M] [Fintype E] [DecidableEq E]
    (sys : ERIEC.Adj.ConvSystem M E),
    linearizeRelation sys.sigmaRel = (linearizeRelation sys.alphaRel).adjoint)

#print axioms ERIEC.InterfaceLinearization.convSystem_linearization_eq_adjoint

end ERIECV2.Statement.VP2_I1_REL_LIN_001
