import ERIEC.InterfaceLinearization

open ERIEC.InterfaceLinearization

namespace ERIECV2.Statement.VP2_I1_DERIV_BRIDGE_001

#check (ERIEC.InterfaceLinearization.converse_linearization_eq_sensitivity_adjoint :
  ∀ {m e : Nat}
    (sys : ERIEC.Adj.ConvSystem (Fin m) (Fin e))
    (response : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (base : EuclideanSpace ℝ (Fin m)),
    RealizesSensitivityAt sys.alphaRel response base →
      linearizeRelation sys.sigmaRel =
        (ERIEC.Sens.T_w_adjoint response base).toLinearMap)

#print axioms ERIEC.InterfaceLinearization.converse_linearization_eq_sensitivity_adjoint

end ERIECV2.Statement.VP2_I1_DERIV_BRIDGE_001
