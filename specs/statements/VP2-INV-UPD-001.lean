import ERIEC.Invariance.Dynamic

open ERIEC.Invariance ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_INV_UPD_001

#check (ERIEC.Invariance.upd_bisim :
  ∀ {C E C' E' W : Type*}
    (hC : C ≃ C') (hE : E ≃ E')
    (phi : W → Set C → Set C) (phi' : W → Set C' → Set C')
    (theta : W → Set E → Set E) (theta' : W → Set E' → Set E')
    (drift : W → Set C → W) (drift' : W → Set C' → W)
    (hPhi : ∀ w K, image hC (phi w K) = phi' w (image hC K))
    (hTheta : ∀ w X, image hE (theta w X) = theta' w (image hE X))
    (hDrift : DriftEquivariant hC drift drift') (c : Conf C E W),
    mapConf hC hE (upd phi theta drift c) =
      upd phi' theta' drift' (mapConf hC hE c))

end ERIECV2.Statement.VP2_INV_UPD_001
