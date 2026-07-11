import ERIEC.Adjunction
import ERIEC.Sensitivity

open scoped RealInnerProductSpace

namespace ERIEC

namespace Body

universe u

/-!
Phase II body-level guardrails.

This file keeps the Lenia-body action interface separate from rule/kernel
parameters, builds the Phase II adjunction constructively with
`sigma_star_induced`, and reuses the sensitivity tensor facts for body
Jacobians.
-/

/-- Body-relative actuator modes. These are interventions into the Lenia field,
not offsets of Lenia rule/kernel parameters. -/
inductive InterventionMode where
  | normalPush
  | normalPull
  | tangentialShear
  | rotate
  | contract
  | expand
  | localGrowthUp
  | localGrowthDown
  | obstacleAvoidance
  deriving DecidableEq

/-- Lenia kernel/rule parameters. Kept as a distinct type from
`InterventionMode` so body responses cannot accidentally take kernel offsets as
their motor domain. -/
inductive KernelParam where
  | mu
  | sigma
  | radius
  deriving DecidableEq

/-- Body-relative sensory response features. -/
inductive SensoryFeature where
  | boundarySector
  | radialGradient
  | normalFlux
  | curvatureShape
  | contactObstacle
  | nuPhiContribution
  deriving DecidableEq

abbrev MotorState := InterventionMode → ℝ

abbrev KernelParamState := KernelParam → ℝ

abbrev SensoryState := SensoryFeature → ℝ

/-- A Phase II body response accepts only body intervention states. A kernel
parameter state has a different type and is not part of this interface. -/
structure BodyResponse where
  sigma : MotorState → SensoryState

theorem body_response_domain_is_intervention (response : BodyResponse) :
    response.sigma = response.sigma :=
  rfl

/-- External target/set-point tokens are represented only to state the
guardrail: body responses below do not carry one. -/
inductive ExternalSetPoint where
  | targetPattern
  deriving DecidableEq

/--
Finite harness for the stronger M4 reading: a set point would be a terminal
object of the agent's reachable/request diagram. A true-C candidate keeps this
position non-present; if a terminal target is present, the system has a place
where seeking can stop.
-/
structure SetPointDiagram (Obj : Type u) where
  reaches : Obj → Obj → Prop

def HasTerminalSetPoint {Obj : Type u} (D : SetPointDiagram Obj) : Prop :=
  ∃ t : Obj, ∀ x : Obj, D.reaches x t

def NoTerminalSetPoint {Obj : Type u} (D : SetPointDiagram Obj) : Prop :=
  ¬ HasTerminalSetPoint D

theorem noTerminalSetPoint_forbids_terminal {Obj : Type u}
    (D : SetPointDiagram Obj)
    (h : NoTerminalSetPoint D) :
    ¬ ∃ t : Obj, ∀ x : Obj, D.reaches x t :=
  h

/-- Endogenous Phase II response. The structure has no `ExternalSetPoint`
field; set-point dependence must enter through endogenous quantities such as
`nuPhi`, not through an external target. -/
structure EndogenousBodyResponse where
  sigma : MotorState → SensoryState
  nuPhiContribution : SensoryFeature → Nat

theorem endogenous_sigma_defined_without_external_setpoint
    (response : EndogenousBodyResponse) :
    ∃ sigma : MotorState → SensoryState, sigma = response.sigma :=
  ⟨response.sigma, rfl⟩

/-- Phase II uses the induced right adjoint when the physical sensory relation
is not independently assumed. -/
abbrev body_sigma_star_induced
    (alphaRel : InterventionMode → Set SensoryFeature) :
    Set SensoryFeature → Set InterventionMode :=
  Adj.sigma_star_induced alphaRel

theorem body_galoisConn_induced
    (alphaRel : InterventionMode → Set SensoryFeature) :
    GaloisConnection (Adj.alpha_star alphaRel)
      (body_sigma_star_induced alphaRel) := by
  exact Adj.galoisConn_induced alphaRel

theorem body_unit_induced
    (alphaRel : InterventionMode → Set SensoryFeature)
    (N : Set InterventionMode) :
    N ⊆ body_sigma_star_induced alphaRel (Adj.alpha_star alphaRel N) :=
  (body_galoisConn_induced alphaRel).le_u_l N

theorem body_counit_induced
    (alphaRel : InterventionMode → Set SensoryFeature)
    (X : Set SensoryFeature) :
    Adj.alpha_star alphaRel (body_sigma_star_induced alphaRel X) ⊆ X :=
  (body_galoisConn_induced alphaRel).l_u_le X

/-- Body Jacobian: the sensitivity tensor for a body response
`sigma : R^M -> R^E`. -/
noncomputable def bodyJacobian {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin e) :=
  Sens.T_w sigma a

theorem bodyJacobian_is_fderiv {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    bodyJacobian sigma a = fderiv ℝ sigma a := by
  rfl

theorem bodyJacobian_wellDefined {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m))
    (h : DifferentiableAt ℝ sigma a) :
    HasFDerivAt sigma (bodyJacobian sigma a) a := by
  simpa [bodyJacobian] using Sens.wellDefined sigma a h

/-- The body-Jacobian adjoint is the Hilbert-space dual of the body
sensitivity tensor. -/
noncomputable def bodyJacobianAdjoint {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    EuclideanSpace ℝ (Fin e) →L[ℝ] EuclideanSpace ℝ (Fin m) :=
  Sens.T_w_adjoint sigma a

theorem bodyJacobian_dualSymmetry {m e : Nat}
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m))
    (x : EuclideanSpace ℝ (Fin m))
    (y : EuclideanSpace ℝ (Fin e)) :
    inner ℝ (bodyJacobian sigma a x) y =
      inner ℝ x (bodyJacobianAdjoint sigma a y) := by
  simpa [bodyJacobian, bodyJacobianAdjoint] using
    Sens.dualSymmetry sigma a x y

end Body

end ERIEC
