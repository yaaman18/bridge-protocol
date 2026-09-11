namespace ERIEC.ModelAuditExperiment

universe u v

/-- A symmetry-fixed object cannot be assigned a choice by an equivariant selector
when the induced action on choices has no fixed point. No phenomenal claim follows. -/
theorem no_equivariant_selector_at_fixed_object {X : Type u} {I : Type v}
    (moveObject : X → X) (moveChoice : I → I) (x : X)
    (fixed : moveObject x = x) (noFixedChoice : ∀ i, moveChoice i ≠ i) :
    ¬ ∃ select : X → I, ∀ y, select (moveObject y) = moveChoice (select y) :=
  fun ⟨select, equivariant⟩ =>
    noFixedChoice (select x) ((equivariant x).symm.trans (congrArg select fixed))

end ERIEC.ModelAuditExperiment
