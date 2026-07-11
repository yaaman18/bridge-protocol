import ERIEC.Adjunction
import ERIEC.Sensitivity
import Mathlib.Analysis.InnerProductSpace.Adjoint

namespace ERIEC
namespace InterfaceLinearization

/-- Incidence matrix of a finite relation, oriented from its domain to its
codomain. -/
noncomputable def relationMatrix {M E : Type*}
    (rel : M → Set E) : Matrix E M ℝ :=
  by
    classical
    exact fun e m ↦ if e ∈ rel m then 1 else 0

/-- Converse relations have transposed incidence matrices. -/
theorem relationMatrix_transpose_of_converse {M E : Type*}
    (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (hConv : ∀ m e, e ∈ alphaRel m ↔ m ∈ sigmaRel e) :
    relationMatrix sigmaRel = (relationMatrix alphaRel).transpose := by
  classical
  ext m e
  simp only [relationMatrix, Matrix.transpose_apply]
  rw [hConv m e]

/-- Euclidean linearization of a finite relation. -/
noncomputable def linearizeRelation {M E : Type*}
    [Fintype M] [DecidableEq M] [Fintype E] [DecidableEq E]
    (rel : M → Set E) :
    EuclideanSpace ℝ M →ₗ[ℝ] EuclideanSpace ℝ E :=
  Matrix.toEuclideanLin (relationMatrix rel)

/-- Finite relational converse becomes the Hilbert-space adjoint after
incidence-matrix linearization. -/
theorem linearize_converse_eq_adjoint {M E : Type*}
    [Fintype M] [DecidableEq M] [Fintype E] [DecidableEq E]
    (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (hConv : ∀ m e, e ∈ alphaRel m ↔ m ∈ sigmaRel e) :
    linearizeRelation sigmaRel = (linearizeRelation alphaRel).adjoint := by
  rw [linearizeRelation, linearizeRelation,
    relationMatrix_transpose_of_converse alphaRel sigmaRel hConv]
  simpa using
    (Matrix.toEuclideanLin_conjTranspose_eq_adjoint (relationMatrix alphaRel))

/-- The `hConv` field supplies exactly the compatibility needed by the finite
relation-to-linear interface. -/
theorem convSystem_linearization_eq_adjoint {M E : Type*}
    [Fintype M] [DecidableEq M] [Fintype E] [DecidableEq E]
    (sys : Adj.ConvSystem M E) :
    linearizeRelation sys.sigmaRel = (linearizeRelation sys.alphaRel).adjoint :=
  linearize_converse_eq_adjoint sys.alphaRel sys.sigmaRel sys.hConv

/-- Exact interface condition saying that the physical sensitivity at a point
realizes the canonical incidence-matrix linearization of a finite relation. -/
def RealizesSensitivityAt {m e : Nat}
    (rel : Fin m → Set (Fin e))
    (response : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (base : EuclideanSpace ℝ (Fin m)) : Prop :=
  (Sens.T_w response base).toLinearMap = linearizeRelation rel

/-- Under the explicit realization condition, the reverse relational shadow is
exactly the Hilbert adjoint of the physical sensitivity tensor. -/
theorem converse_linearization_eq_sensitivity_adjoint {m e : Nat}
    (sys : Adj.ConvSystem (Fin m) (Fin e))
    (response : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (base : EuclideanSpace ℝ (Fin m))
    (hRealizes : RealizesSensitivityAt sys.alphaRel response base) :
    linearizeRelation sys.sigmaRel = (Sens.T_w_adjoint response base).toLinearMap := by
  rw [convSystem_linearization_eq_adjoint, ← hRealizes]
  exact ContinuousLinearMap.adjoint_toLinearMap (Sens.T_w response base)

/-- An isomorphism of finite relations, retaining both carrier equivalences and
the exact relation-preservation square. -/
structure RelationIso {M E M' E' : Type*}
    (rel : M → Set E) (rel' : M' → Set E') where
  domain : M ≃ M'
  codomain : E ≃ E'
  map_iff : ∀ m e, e ∈ rel m ↔ codomain e ∈ rel' (domain m)

/-- Incidence-matrix linearization is natural under relation isomorphism:
reindexing rows and columns gives exactly the target relation matrix. -/
theorem relationMatrix_reindex_natural {M E M' E' : Type*}
    {rel : M → Set E} {rel' : M' → Set E'}
    (h : RelationIso rel rel') :
    Matrix.reindex h.codomain h.domain (relationMatrix rel) =
      relationMatrix rel' := by
  classical
  ext e' m'
  change (if h.codomain.symm e' ∈ rel (h.domain.symm m') then 1 else 0) =
    (if e' ∈ rel' m' then 1 else 0)
  rw [h.map_iff (h.domain.symm m') (h.codomain.symm e')]
  simp

/-- A general relation morphism preserves positive relation evidence but need
not reflect it. -/
structure RelationHom {M E M' E' : Type*}
    (rel : M → Set E) (rel' : M' → Set E') where
  onDomain : M → M'
  onCodomain : E → E'
  map_rel : ∀ m e, e ∈ rel m → onCodomain e ∈ rel' (onDomain m)

/-- Incidence linearization is lax-natural for arbitrary relation morphisms. -/
theorem relationMatrix_lax_natural {M E M' E' : Type*}
    {rel : M → Set E} {rel' : M' → Set E'}
    (h : RelationHom rel rel') (m : M) (e : E) :
    relationMatrix rel e m ≤
      relationMatrix rel' (h.onCodomain e) (h.onDomain m) := by
  classical
  by_cases hmem : e ∈ rel m
  · simp [relationMatrix, hmem, h.map_rel m e hmem]
  · by_cases htarget : h.onCodomain e ∈ rel' (h.onDomain m)
    · simp [relationMatrix, hmem, htarget]
    · simp [relationMatrix, hmem, htarget]

/-- Strict matrix naturality is false for the permissive relation-morphism
class: a morphism may map a missing edge to a present edge. -/
theorem strict_naturality_fails_for_relationHom :
    ∃ (rel rel' : Unit → Set Unit) (h : RelationHom rel rel'),
      relationMatrix rel () () ≠
        relationMatrix rel' (h.onCodomain ()) (h.onDomain ()) := by
  let rel : Unit → Set Unit := fun _ ↦ ∅
  let rel' : Unit → Set Unit := fun _ ↦ Set.univ
  let h : RelationHom rel rel' :=
    { onDomain := id
      onCodomain := id
      map_rel := by simp [rel] }
  refine ⟨rel, rel', h, ?_⟩
  norm_num [relationMatrix, rel, rel', h]

end InterfaceLinearization
end ERIEC
