import Mathlib.Analysis.Calculus.FDeriv.Basic
import Mathlib.Analysis.InnerProductSpace.Adjoint
import Mathlib.Analysis.InnerProductSpace.PiL2

open scoped RealInnerProductSpace

namespace ERIEC

namespace Sens

noncomputable def T_w {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) -> EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin e) :=
  fderiv ℝ sigma a

theorem isDerivative {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) -> EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    T_w sigma a = fderiv ℝ sigma a := rfl

theorem wellDefined {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) -> EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m))
    (h : DifferentiableAt ℝ sigma a) :
    HasFDerivAt sigma (T_w sigma a) a := by
  simpa [T_w] using h.hasFDerivAt

noncomputable def T_w_adjoint {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) -> EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    EuclideanSpace ℝ (Fin e) →L[ℝ] EuclideanSpace ℝ (Fin m) :=
  ContinuousLinearMap.adjoint (T_w sigma a)

theorem dualSymmetry {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) -> EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m))
    (x : EuclideanSpace ℝ (Fin m))
    (y : EuclideanSpace ℝ (Fin e)) :
    inner ℝ (T_w sigma a x) y = inner ℝ x (T_w_adjoint sigma a y) := by
  simpa [T_w_adjoint] using
    (ContinuousLinearMap.adjoint_inner_right (T_w sigma a) x y).symm

/-- Adjointness alone does not provide an order-unit inequality: the zero
operator strictly contracts a nonzero vector even after `T†T`. -/
theorem not_id_le_adjoint_comp :
    ∃ T : ℝ →L[ℝ] ℝ, ∃ x : ℝ,
      ‖ContinuousLinearMap.adjoint T (T x)‖ < ‖x‖ := by
  refine ⟨0, 1, ?_⟩
  norm_num

end Sens

end ERIEC
