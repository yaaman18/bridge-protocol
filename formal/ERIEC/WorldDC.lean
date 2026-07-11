import ERIEC.DC
import ERIEC.World

open scoped RealInnerProductSpace

namespace ERIEC

namespace WorldDC

/-!
Weak formal bridge between double closure and actuated world.

`DC` currently lives in the discrete Set/Poset layer, while `World.worldLoop`
lives in the finite-dimensional Hilbert layer. A full Prop 5.3 proof needs an
additional representation map from discrete sensorimotor closure to a vector
subspace. This file records the proofable core: when a DC state is paired with
a nonzero fixed direction of the world loop, the hinge is nonempty and the
world is nontrivial.

This is intentionally a consistency harness, not an equivalence proof. In
particular, `WldNontrivial L` alone does not construct the self-maintenance,
hinge, and boundary witnesses required by `DC`.
-/

/-- A DC state equipped with a nonzero fixed direction of a loop operator. -/
structure DCWorldBridge {M E C S : Type*} {m : Nat}
    (dc : DC M E C S)
    (L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)) where
  direction : EuclideanSpace ℝ (Fin m)
  direction_nonzero : direction ≠ 0
  direction_fixed : World.WorldFixedVector L direction

theorem wld_nontrivial_of_bridge {M E C S : Type*} {m : Nat}
    {dc : DC M E C S}
    {L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)}
    (bridge : DCWorldBridge dc L) :
    World.WldNontrivial L :=
  World.fixedVector_witnesses_nontrivial
    bridge.direction_nonzero bridge.direction_fixed

theorem act_nonempty_of_bridge {M E C S : Type*} {m : Nat}
    {dc : DC M E C S}
    {L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)}
    (_bridge : DCWorldBridge dc L) :
    (Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty :=
  DC.act_nonempty dc

/-- Weak Prop 5.3 core: DC plus a fixed world direction gives both sides. -/
theorem dc_and_world_of_bridge {M E C S : Type*} {m : Nat}
    {dc : DC M E C S}
    {L : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)}
    (bridge : DCWorldBridge dc L) :
    (Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty ∧
      World.WldNontrivial L :=
  ⟨act_nonempty_of_bridge bridge, wld_nontrivial_of_bridge bridge⟩

/-- Specialized bridge for the concrete world loop `T^* ∘ T`. -/
theorem dc_and_worldLoop_of_fixed {M E C S : Type*} {m e : Nat}
    (dc : DC M E C S)
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m))
    (x : EuclideanSpace ℝ (Fin m))
    (hx0 : x ≠ 0)
    (hfix : World.WorldFixedVector (World.worldLoop sigma a) x) :
    (Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty ∧
      World.WldNontrivial (World.worldLoop sigma a) := by
  exact dc_and_world_of_bridge
    (dc := dc)
    (L := World.worldLoop sigma a)
    { direction := x
      direction_nonzero := hx0
      direction_fixed := hfix }

/-- The zero loop has no nonzero fixed direction. -/
theorem zero_loop_not_nontrivial {m : Nat} :
    ¬ World.WldNontrivial
      (0 : EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin m)) := by
  rintro ⟨x, hx, hfix⟩
  apply hx
  simpa [World.WorldFixedVector] using hfix.symm

namespace Countermodel

/-- A one-point double-closure state satisfying all four DC clauses. -/
def unitDC : DC Unit Unit Unit Unit where
  alphaRel := fun _ => {()}
  sigmaRel := fun _ => {()}
  piRel := fun _ => {()}
  rhoRel := fun _ => {()}
  kappa := fun _ => {()}
  epsilon := fun _ => {()}
  boundary := {()}
  s := ()
  hSelf := by
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star]
  hSMC := by
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star]
  hAct := by
    exact ⟨(), by simp [Hinge.Act, Closure.rho_star, Adj.sigma_star]⟩
  hBound := by
    exact ⟨(), by simp⟩

/-- Fixing the boundary to the empty set makes the fourth DC clause
uninhabitable, independently of all other relations. -/
theorem no_dc_with_empty_boundary :
    ¬ ∃ dc : DC Unit Unit Unit Unit, dc.boundary = ∅ := by
  rintro ⟨dc, hBoundary⟩
  rcases dc.hBound with ⟨c, _hcKappa, hcBoundary⟩
  rw [hBoundary] at hcBoundary
  exact hcBoundary

end Countermodel

/-- Forward countermodel: a DC witness and a trivial world loop coexist in
the same existential witness. -/
theorem no_forward_unconditional :
    ∃ (dc : DC Unit Unit Unit Unit)
      (L : EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1)),
      ¬ World.WldNontrivial L := by
  exact ⟨Countermodel.unitDC, 0, zero_loop_not_nontrivial⟩

/-- Backward countermodel: the identity loop has a nonzero fixed direction,
while an empty boundary makes every DC witness impossible. -/
theorem no_backward_unconditional :
    ∃ L : EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1),
      World.WldNontrivial L ∧
        ¬ ∃ dc : DC Unit Unit Unit Unit, dc.boundary = ∅ := by
  let L : EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1) :=
    ContinuousLinearMap.id ℝ _
  let x : EuclideanSpace ℝ (Fin 1) := EuclideanSpace.single 0 1
  refine ⟨L, ?_, Countermodel.no_dc_with_empty_boundary⟩
  refine ⟨x, ?_, ?_⟩
  · simp [x]
  · simp [World.WorldFixedVector, L]

end WorldDC

end ERIEC
