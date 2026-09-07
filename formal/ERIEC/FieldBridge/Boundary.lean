import Mathlib.Data.Set.Basic

namespace ERIEC

namespace FieldBridge

universe u

/-!
The boundary witness belongs to the observation layer.  Its neighborhood is
explicit data; periodicity is supplied by the finite Julia instantiation and
is not asserted for every abstract neighborhood.
-/

/-- A boundary is exact when its cells are precisely the supported cells with
at least one neighbor outside the support. -/
structure PeriodicBoundaryWitness (Cell : Type u) where
  neighbors : Cell → Set Cell
  support : Set Cell
  boundary : Set Cell
  exact_boundary : ∀ cell,
    cell ∈ boundary ↔
      cell ∈ support ∧ ∃ neighbor, neighbor ∈ neighbors cell ∧ neighbor ∉ support

theorem boundary_subset_support {Cell : Type u}
    (witness : PeriodicBoundaryWitness Cell) :
    witness.boundary ⊆ witness.support := by
  intro cell hcell
  exact (witness.exact_boundary cell).mp hcell |>.1

end FieldBridge

end ERIEC
