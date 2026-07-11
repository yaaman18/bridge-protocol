import ERIEC.World

namespace ERIEC
namespace Invariance

/-- Conjugation of a continuous operator by a unitary equivalence. -/
noncomputable def unitaryConjugate {m n : Nat}
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)) :
    EuclideanSpace ℝ (Fin n) →L[ℝ] EuclideanSpace ℝ (Fin n) :=
  U.toLinearIsometry.toContinuousLinearMap.comp
    (L.comp U.symm.toLinearIsometry.toContinuousLinearMap)

@[simp] theorem unitaryConjugate_apply {m n : Nat}
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    (x : EuclideanSpace ℝ (Fin m)) :
    unitaryConjugate U L (U x) = U (L x) := by
  simp [unitaryConjugate]

private theorem unitary_rayleigh {m n : Nat}
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    (x : EuclideanSpace ℝ (Fin m)) :
    (unitaryConjugate U L).rayleighQuotient (U x) = L.rayleighQuotient x := by
  simp only [ContinuousLinearMap.rayleighQuotient,
    ContinuousLinearMap.reApplyInnerSelf_apply, unitaryConjugate_apply,
    U.inner_map_map, LinearIsometryEquiv.norm_map]

private theorem lambdaMax_unitary {m n : Nat} [NeZero m] [NeZero n]
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)) :
    World.lambdaMax (unitaryConjugate U L) = World.lambdaMax L := by
  let f := fun x : {x : EuclideanSpace ℝ (Fin m) // x ≠ 0} => L.rayleighQuotient x
  let g := fun y : {y : EuclideanSpace ℝ (Fin n) // y ≠ 0} =>
    (unitaryConjugate U L).rayleighQuotient y
  have hf : BddAbove (Set.range f) := by
    refine ⟨‖L‖, ?_⟩
    rintro _ ⟨x, rfl⟩
    exact (le_abs_self _).trans (L.rayleighQuotient_le_norm x)
  have hg : BddAbove (Set.range g) := by
    refine ⟨‖unitaryConjugate U L‖, ?_⟩
    rintro _ ⟨y, rfl⟩
    exact (le_abs_self _).trans ((unitaryConjugate U L).rayleighQuotient_le_norm y)
  let im : Fin m := ⟨0, Nat.pos_of_ne_zero (NeZero.ne m)⟩
  let inm : Fin n := ⟨0, Nat.pos_of_ne_zero (NeZero.ne n)⟩
  let xm : EuclideanSpace ℝ (Fin m) := EuclideanSpace.single im 1
  let xn : EuclideanSpace ℝ (Fin n) := EuclideanSpace.single inm 1
  have hxm : xm ≠ 0 := by simp [xm]
  have hxn : xn ≠ 0 := by simp [xn]
  letI : Nonempty {x : EuclideanSpace ℝ (Fin m) // x ≠ 0} := ⟨⟨xm, hxm⟩⟩
  letI : Nonempty {y : EuclideanSpace ℝ (Fin n) // y ≠ 0} := ⟨⟨xn, hxn⟩⟩
  change (⨆ y, g y) = ⨆ x, f x
  apply le_antisymm
  · apply ciSup_le
    intro y
    let x : EuclideanSpace ℝ (Fin m) := U.symm y
    have hx : x ≠ 0 := by simp [x, y.property]
    calc
      g y = f (⟨x, hx⟩ : {x : EuclideanSpace ℝ (Fin m) // x ≠ 0}) := by
        simpa [f, g, x] using unitary_rayleigh U L (U.symm y)
      _ ≤ ⨆ x, f x := le_ciSup hf _
  · apply ciSup_le
    intro x
    have hUx : U x ≠ 0 := by simp [x.property]
    calc
      f x = g (⟨U x, hUx⟩ : {y : EuclideanSpace ℝ (Fin n) // y ≠ 0}) := by
        exact (unitary_rayleigh U L x).symm
      _ ≤ ⨆ y, g y := le_ciSup hg _

private theorem band_unitary {m n : Nat}
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    (eta : ℝ) :
    Submodule.map U.toLinearEquiv.toLinearMap (World.Wld_band L eta) =
      World.Wld_band (unitaryConjugate U L) eta := by
  apply le_antisymm
  · rw [World.Wld_band, Submodule.map_span]
    apply Submodule.span_le.mpr
    rintro y ⟨x, ⟨lambda, hBand, hEigen⟩, rfl⟩
    apply Submodule.subset_span
    refine ⟨lambda, hBand, ?_⟩
    change unitaryConjugate U L (U x) = lambda • U x
    rw [unitaryConjugate_apply, hEigen, map_smul]
  · apply Submodule.span_le.mpr
    rintro y ⟨lambda, hBand, hEigen⟩
    apply Submodule.mem_map.mpr
    refine ⟨U.symm y, ?_, by simp⟩
    apply Submodule.subset_span
    refine ⟨lambda, hBand, ?_⟩
    apply U.injective
    simpa [hEigen] using (unitaryConjugate_apply U L (U.symm y)).symm

private theorem eigenvalue_unitary {m n : Nat}
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    (lambda : ℝ) :
    Module.End.HasEigenvalue L.toLinearMap lambda ↔
      Module.End.HasEigenvalue (unitaryConjugate U L).toLinearMap lambda := by
  constructor
  · intro hEigenvalue
    obtain ⟨x, hx⟩ := hEigenvalue.exists_hasEigenvector
    apply Module.End.hasEigenvalue_of_hasEigenvector (x := U x)
    refine ⟨Module.End.mem_eigenspace_iff.mpr ?_, by simpa using U.injective.ne_iff.mpr hx.2⟩
    change unitaryConjugate U L (U x) = lambda • U x
    rw [unitaryConjugate_apply]
    have hxEq : L x = lambda • x := hx.apply_eq_smul
    rw [hxEq, map_smul]
  · intro hEigenvalue
    obtain ⟨y, hy⟩ := hEigenvalue.exists_hasEigenvector
    apply Module.End.hasEigenvalue_of_hasEigenvector (x := U.symm y)
    refine ⟨Module.End.mem_eigenspace_iff.mpr ?_, by
      simpa using U.symm.injective.ne_iff.mpr hy.2⟩
    change L (U.symm y) = lambda • U.symm y
    apply U.injective
    calc
      U (L (U.symm y)) = unitaryConjugate U L y := by
        simpa using (unitaryConjugate_apply U L (U.symm y)).symm
      _ = lambda • y := hy.apply_eq_smul
      _ = U (lambda • U.symm y) := by simp

/-- Unitary conjugacy preserves the spectrum, spectral band, `χ`, and
existence of a nonzero fixed direction. -/
theorem unitary_conj {m n : Nat} [NeZero m] [NeZero n]
    (U : EuclideanSpace ℝ (Fin m) ≃ₗᵢ[ℝ] EuclideanSpace ℝ (Fin n))
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m))
    (eta : ℝ) :
    (∀ lambda : ℝ, Module.End.HasEigenvalue L.toLinearMap lambda ↔
        Module.End.HasEigenvalue (unitaryConjugate U L).toLinearMap lambda) ∧
      Submodule.map U.toLinearEquiv.toLinearMap (World.Wld_band L eta) =
          World.Wld_band (unitaryConjugate U L) eta ∧
      World.chi (unitaryConjugate U L) = World.chi L ∧
      (World.WldNontrivial (unitaryConjugate U L) ↔ World.WldNontrivial L) := by
  refine ⟨eigenvalue_unitary U L, band_unitary U L eta, ?_, ?_⟩
  · simp [World.chi, lambdaMax_unitary U L]
  · constructor
    · rintro ⟨y, hy, hfix⟩
      refine ⟨U.symm y, by simpa using hy, ?_⟩
      change L (U.symm y) = U.symm y
      apply U.injective
      calc
        U (L (U.symm y)) = unitaryConjugate U L y := by
          simpa using (unitaryConjugate_apply U L (U.symm y)).symm
        _ = y := hfix
        _ = U (U.symm y) := by simp
    · rintro ⟨x, hx, hfix⟩
      refine ⟨U x, by simpa using hx, ?_⟩
      change unitaryConjugate U L (U x) = U x
      rw [unitaryConjugate_apply, hfix]
end Invariance
end ERIEC
