import ERIEC.Invariance.Spectral

open ERIEC.Invariance

namespace ERIECV2.Statement.VP2_INV_UNITARY_001

#check ERIEC.Invariance.eigenspace_unitary
#check ERIEC.Invariance.wld_band_unitary
#check ERIEC.Invariance.eigenvalue_unitary

#check (ERIEC.Invariance.unitary_conj :
  ∀ {m n : Nat} [NeZero m] [NeZero n]
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    (eta : ℝ),
    (∀ lambda : ℝ, Module.End.HasEigenvalue L.toLinearMap lambda ↔
      Module.End.HasEigenvalue (unitaryConjugate U L).toLinearMap lambda) ∧
    Submodule.map U.toLinearEquiv.toLinearMap (ERIEC.World.Wld_band L eta) =
      ERIEC.World.Wld_band (unitaryConjugate U L) eta ∧
    ERIEC.World.chi (unitaryConjugate U L) = ERIEC.World.chi L ∧
    (ERIEC.World.WldNontrivial (unitaryConjugate U L) ↔
      ERIEC.World.WldNontrivial L))

end ERIECV2.Statement.VP2_INV_UNITARY_001
