import ERIEC.Invariance.Dynamic

namespace ERIECV2.Statement.VP2_INV_DRIFT_001

#check (ERIEC.Invariance.DriftEquivariant :
  ∀ {C C' W : Type*} (hC : C ≃ C')
    (drift : W → Set C → W) (drift' : W → Set C' → W), Prop)

end ERIECV2.Statement.VP2_INV_DRIFT_001
