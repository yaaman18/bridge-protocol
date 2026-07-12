import Mathlib.LinearAlgebra.Eigenspace.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Analysis.InnerProductSpace.Basic
import ERIEC.Markers

namespace ERIEC

namespace AnalyticFM4

/-!
Analytic refinement of the finite FM4 skeleton.

This module keeps the existing `Markers.FM4Iso` unchanged.  It supplies the
additional real-linear, inner-product, eigenspace, and spectral-projection
data required by v5.2 §25.6 when the representation space is `R²`.
-/

/-- The real two-dimensional action representation space. -/
abbrev R2 := ℝ × ℝ

/-- The standard Euclidean inner product on `R²`. -/
def inner (x y : R2) : ℝ :=
  x.1 * y.1 + x.2 * y.2

/-- Squared Euclidean norm, sufficient for the finite unitary witness. -/
def normSq (x : R2) : ℝ :=
  inner x x

/-- The coordinate-exchange linear equivalence on `R²`. -/
def coordinateSwap : R2 ≃ₗ[ℝ] R2 where
  toFun := fun x => (x.2, x.1)
  invFun := fun x => (x.2, x.1)
  left_inv := by
    intro x
    rcases x with ⟨x₁, x₂⟩
    rfl
  right_inv := by
    intro x
    rcases x with ⟨x₁, x₂⟩
    rfl
  map_add' := by
    intro x y
    rcases x with ⟨x₁, x₂⟩
    rcases y with ⟨y₁, y₂⟩
    rfl
  map_smul' := by
    intro a x
    rcases x with ⟨x₁, x₂⟩
    rfl

/-- A real unitary is a real-linear equivalence preserving the Euclidean
inner product. -/
structure IsUnitary (U : R2 ≃ₗ[ℝ] R2) : Prop where
  inner_preserves : ∀ x y, inner (U x) (U y) = inner x y

/-- The coordinate exchange is unitary. -/
theorem coordinateSwap_unitary : IsUnitary coordinateSwap where
  inner_preserves := by
    intro x y
    rcases x with ⟨x₁, x₂⟩
    rcases y with ⟨y₁, y₂⟩
    simp [coordinateSwap, inner, add_comm]

theorem coordinateSwap_normSq (x : R2) :
    normSq (coordinateSwap x) = normSq x :=
  coordinateSwap_unitary.inner_preserves x x

/-- Analytic FM4 data: a real-linear operator, one of its eigenspaces, and a
spectral projection onto that eigenspace. -/
structure Frame (A : Type*) where
  representation : A → R2
  operator : Module.End ℝ R2
  eigenvalue : ℝ
  spectralProjection : Module.End ℝ R2
  projection_mem_eigenspace :
    ∀ v, spectralProjection v ∈ operator.eigenspace eigenvalue
  projection_fixes_eigenspace :
    ∀ v, v ∈ operator.eigenspace eigenvalue → spectralProjection v = v

/-- Analytic form of FM4 at the fixed eigenspace. -/
def FM4 (F : Frame A) (a : A) : Prop :=
  F.spectralProjection (F.representation a) ≠ 0

/-- A unitary analytic FM4 isomorphism.  Besides transporting representations,
it conjugates the operator and commutes with the spectral projection. -/
structure Iso {A A' : Type*} (F : Frame A) (F' : Frame A') where
  hA : A ≃ A'
  U : R2 ≃ₗ[ℝ] R2
  unitary : IsUnitary U
  representation_preserves :
    ∀ a, U (F.representation a) = F'.representation (hA a)
  eigenvalue_preserves : F.eigenvalue = F'.eigenvalue
  operator_commutes :
    U.toLinearMap.comp F.operator = F'.operator.comp U.toLinearMap
  projection_commutes :
    U.toLinearMap.comp F.spectralProjection =
      F'.spectralProjection.comp U.toLinearMap

/-- The unitary carries the chosen eigenspace to the corresponding
eigenspace of the conjugate operator. -/
theorem eigenspace_preserved {A A' : Type*} {F : Frame A} {F' : Frame A'}
    (h : Iso F F') (v : R2) :
    v ∈ F.operator.eigenspace F.eigenvalue ↔
      h.U v ∈ F'.operator.eigenspace F'.eigenvalue := by
  rw [Module.End.mem_eigenspace_iff, Module.End.mem_eigenspace_iff]
  constructor
  · intro hv
    calc
      F'.operator (h.U v) = h.U (F.operator v) := by
        exact (LinearMap.congr_fun h.operator_commutes v).symm
      _ = h.U (F.eigenvalue • v) := by rw [hv]
      _ = F'.eigenvalue • h.U v := by
        simpa only [h.eigenvalue_preserves] using h.U.map_smul F.eigenvalue v
  · intro hv
    apply h.U.injective
    calc
      h.U (F.operator v) = F'.operator (h.U v) :=
        LinearMap.congr_fun h.operator_commutes v
      _ = F'.eigenvalue • h.U v := hv
      _ = h.U (F.eigenvalue • v) := by
        simpa only [h.eigenvalue_preserves] using (h.U.map_smul F.eigenvalue v).symm

/-- The spectral projection commutes with the unitary on every vector. -/
theorem projection_preserved {A A' : Type*} {F : Frame A} {F' : Frame A'}
    (h : Iso F F') (v : R2) :
    h.U (F.spectralProjection v) = F'.spectralProjection (h.U v) :=
  LinearMap.congr_fun h.projection_commutes v

/-- Analytic FM4 is invariant under a unitary analytic isomorphism. -/
theorem fm4_invariant {A A' : Type*} {F : Frame A} {F' : Frame A'}
    (h : Iso F F') (a : A) :
    FM4 F a ↔ FM4 F' (h.hA a) := by
  unfold FM4
  constructor
  · intro hfm4 hzero
    apply hfm4
    apply h.U.injective
    calc
      h.U (F.spectralProjection (F.representation a)) =
          F'.spectralProjection (h.U (F.representation a)) :=
        projection_preserved h (F.representation a)
      _ = F'.spectralProjection (F'.representation (h.hA a)) := by
        rw [h.representation_preserves a]
      _ = h.U 0 := by simp [hzero]
  · intro hfm4 hzero
    apply hfm4
    calc
      F'.spectralProjection (F'.representation (h.hA a)) =
          F'.spectralProjection (h.U (F.representation a)) := by
        rw [h.representation_preserves a]
      _ = h.U (F.spectralProjection (F.representation a)) :=
        (projection_preserved h (F.representation a)).symm
      _ = 0 := by simp [hzero]

/-- Hilbert-space generalization of analytic FM4.  Unlike the concrete `R2`
frame above, its unitary field uses Mathlib's `LinearIsometryEquiv` directly. -/
structure HilbertFrame (A H : Type*) [NormedAddCommGroup H] [InnerProductSpace ℝ H] where
  representation : A → H
  operator : Module.End ℝ H
  eigenvalue : ℝ
  spectralProjection : Module.End ℝ H
  projection_mem_eigenspace :
    ∀ v, spectralProjection v ∈ operator.eigenspace eigenvalue
  projection_fixes_eigenspace :
    ∀ v, v ∈ operator.eigenspace eigenvalue → spectralProjection v = v
  /-- The residual of the projection is orthogonal to the selected
  eigenspace. Together with the preceding two fields this rules out an
  arbitrary retraction being presented as a spectral projection. -/
  projection_residual_orthogonal :
    ∀ v z, z ∈ operator.eigenspace eigenvalue →
      Inner.inner ℝ (v - spectralProjection v) z = 0

/-- Nonzero spectral component in a general real Hilbert-space representation. -/
def HilbertFM4 {H : Type*} [NormedAddCommGroup H] [InnerProductSpace ℝ H]
    (F : HilbertFrame A H) (a : A) : Prop :=
  F.spectralProjection (F.representation a) ≠ 0

/-- A full marker frame together with the Hilbert-space data that its FM4
component denotes. Equality fields prevent the structural marker predicate
from silently referring to a different representation or projection. -/
structure HilbertFullMarkerFrame
    (A E C S W Ω H : Type*) [NormedAddCommGroup H] [InnerProductSpace ℝ H] where
  marker : Markers.FullMarkerFrame A E C S W Ω H
  analytic : HilbertFrame A H
  representation_eq : marker.representation = analytic.representation
  spectralProjection_eq : marker.spectralProjection = analytic.spectralProjection
  zero_eq : marker.zero = 0

/-- The structural FM4 component of a linked full marker frame is exactly
its analytic Hilbert-space FM4 predicate. -/
theorem hilbert_full_marker_fm4_iff
    {A E C S W Ω H : Type*} [NormedAddCommGroup H] [InnerProductSpace ℝ H]
    (F : HilbertFullMarkerFrame A E C S W Ω H) (a : A) :
    Markers.FM4 F.marker.toFM4 a ↔ HilbertFM4 F.analytic a := by
  change F.marker.spectralProjection (F.marker.representation a) ≠ F.marker.zero ↔
    F.analytic.spectralProjection (F.analytic.representation a) ≠ 0
  rw [F.representation_eq, F.spectralProjection_eq, F.zero_eq]

/-- A representation isomorphism whose analytic component is a genuine
Mathlib linear isometry equivalence. -/
structure HilbertIso {A A' H H' : Type*}
    [NormedAddCommGroup H] [InnerProductSpace ℝ H]
    [NormedAddCommGroup H'] [InnerProductSpace ℝ H']
    (F : HilbertFrame A H) (F' : HilbertFrame A' H') where
  hA : A ≃ A'
  U : H ≃ₗᵢ[ℝ] H'
  representation_preserves :
    ∀ a, U (F.representation a) = F'.representation (hA a)
  eigenvalue_preserves : F.eigenvalue = F'.eigenvalue
  operator_commutes :
    U.toLinearEquiv.toLinearMap.comp F.operator =
      F'.operator.comp U.toLinearEquiv.toLinearMap
  projection_commutes :
    U.toLinearEquiv.toLinearMap.comp F.spectralProjection =
      F'.spectralProjection.comp U.toLinearEquiv.toLinearMap

/-- A standard Hilbert-space unitary transports eigenspaces of conjugate
operators. -/
theorem hilbert_eigenspace_preserved {A A' H H' : Type*}
    [NormedAddCommGroup H] [InnerProductSpace ℝ H]
    [NormedAddCommGroup H'] [InnerProductSpace ℝ H']
    {F : HilbertFrame A H} {F' : HilbertFrame A' H'}
    (h : HilbertIso F F') (v : H) :
    v ∈ F.operator.eigenspace F.eigenvalue ↔
      h.U v ∈ F'.operator.eigenspace F'.eigenvalue := by
  rw [Module.End.mem_eigenspace_iff, Module.End.mem_eigenspace_iff]
  constructor
  · intro hv
    calc
      F'.operator (h.U v) = h.U (F.operator v) := by
        exact (LinearMap.congr_fun h.operator_commutes v).symm
      _ = h.U (F.eigenvalue • v) := by rw [hv]
      _ = F'.eigenvalue • h.U v := by
        simpa only [h.eigenvalue_preserves] using h.U.map_smul F.eigenvalue v
  · intro hv
    apply h.U.injective
    calc
      h.U (F.operator v) = F'.operator (h.U v) :=
        LinearMap.congr_fun h.operator_commutes v
      _ = F'.eigenvalue • h.U v := hv
      _ = h.U (F.eigenvalue • v) := by
        simpa only [h.eigenvalue_preserves] using (h.U.map_smul F.eigenvalue v).symm

/-- Spectral projections commute with the standard Hilbert-space unitary. -/
theorem hilbert_projection_preserved {A A' H H' : Type*}
    [NormedAddCommGroup H] [InnerProductSpace ℝ H]
    [NormedAddCommGroup H'] [InnerProductSpace ℝ H']
    {F : HilbertFrame A H} {F' : HilbertFrame A' H'}
    (h : HilbertIso F F') (v : H) :
    h.U (F.spectralProjection v) = F'.spectralProjection (h.U v) :=
  LinearMap.congr_fun h.projection_commutes v

/-- Analytic FM4 is invariant under a standard Hilbert-space unitary. -/
theorem hilbert_fm4_invariant {A A' H H' : Type*}
    [NormedAddCommGroup H] [InnerProductSpace ℝ H]
    [NormedAddCommGroup H'] [InnerProductSpace ℝ H']
    {F : HilbertFrame A H} {F' : HilbertFrame A' H'}
    (h : HilbertIso F F') (a : A) :
    HilbertFM4 F a ↔ HilbertFM4 F' (h.hA a) := by
  unfold HilbertFM4
  constructor
  · intro hfm4 hzero
    apply hfm4
    apply h.U.injective
    calc
      h.U (F.spectralProjection (F.representation a)) =
          F'.spectralProjection (h.U (F.representation a)) :=
        hilbert_projection_preserved h (F.representation a)
      _ = F'.spectralProjection (F'.representation (h.hA a)) := by
        rw [h.representation_preserves a]
      _ = h.U 0 := by simp [hzero]
  · intro hfm4 hzero
    apply hfm4
    calc
      F'.spectralProjection (F'.representation (h.hA a)) =
          F'.spectralProjection (h.U (F.representation a)) := by
        rw [h.representation_preserves a]
      _ = h.U (F.spectralProjection (F.representation a)) :=
        (hilbert_projection_preserved h (F.representation a)).symm
      _ = 0 := by simp [hzero]

end AnalyticFM4

end ERIEC
