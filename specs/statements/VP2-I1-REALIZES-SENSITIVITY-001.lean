import ERIEC.InterfaceLinearization

namespace ERIECV2.Statement.VP2_I1_REALIZES_SENSITIVITY_001

#check (ERIEC.InterfaceLinearization.RealizesSensitivityAt :
  ∀ {m e : Nat}
    (rel : Fin m → Set (Fin e))
    (response : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (base : EuclideanSpace ℝ (Fin m)),
      Prop)

end ERIECV2.Statement.VP2_I1_REALIZES_SENSITIVITY_001
