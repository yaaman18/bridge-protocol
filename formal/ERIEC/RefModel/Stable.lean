import ERIEC.RefModel.Basic
import ERIEC.Dynamics
import ERIEC.DC
import ERIEC.World
import ERIEC.Value

namespace ERIEC
namespace RefModel

open Dynamics

def pointRel (_ : Unit) : Set Unit := Set.univ

def refPhi (w : Bool) (_ : Set Unit) : Set Unit :=
  if w then ∅ else Set.univ

def refTheta := refPhi

noncomputable def refDrift (w : Bool) (K : Set Unit) : Bool :=
  by
    classical
    exact if w = false ∧ K.Nonempty then true else w

def refKappa : RefState → Set Unit
  | .s0 | .s1 => Set.univ
  | .s2 => ∅

def refEpsilon := refKappa

def refRank : RefState → Bool
  | .s0 => false
  | .s1 | .s2 => true

def refStep (s t : RefState) : Prop := t = next s

noncomputable def stableDynFrame : DynFrame Unit Unit Bool RefState where
  phi := refPhi
  theta := refTheta
  drift := refDrift
  kappa := refKappa
  epsilon := refEpsilon
  omega := refRank
  stepInt := refStep
  h_int := by
    classical
    intro s t h
    subst t
    cases s <;> simp [next, refKappa, refEpsilon, refRank, refPhi, refTheta,
      refDrift, Dynamics.upd]

noncomputable def stableTotalNext : TotalNext stableDynFrame.stepInt where
  next := next
  next_internal := by intro s; rfl

def stableDC : DC Unit Unit Unit RefState where
  alphaRel := pointRel
  sigmaRel := pointRel
  piRel := pointRel
  rhoRel := pointRel
  kappa := refKappa
  epsilon := refEpsilon
  boundary := Set.univ
  s := .s0
  hSelf := by
    intro c _
    simp [refKappa, pointRel, Closure.Phi, Closure.pi_star, Closure.rho_star]
  hSMC := by
    intro e _
    simp [refEpsilon, refKappa, pointRel, Hinge.T_prime,
      Adj.alpha_star, Adj.sigma_star]
  hAct := by
    refine ⟨(), ?_⟩
    simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, refKappa, refEpsilon, pointRel]
  hBound := by simp [refKappa]

noncomputable def stableWorld :
    EuclideanSpace ℝ (Fin 1) →L[ℝ] EuclideanSpace ℝ (Fin 1) :=
  ContinuousLinearMap.id ℝ _

theorem stableWorld_nontrivial : World.WldNontrivial stableWorld := by
  let x : EuclideanSpace ℝ (Fin 1) := EuclideanSpace.single 0 1
  refine ⟨x, by simp [x], ?_⟩
  simp [World.WorldFixedVector, stableWorld]

theorem stableValue_one :
    Value.normalized_V ({()} : Finset Unit) (fun _ : Unit => {()}) () = 1 := by
  norm_num [Value.normalized_V, Value.viabilityContribution]

structure StableReferenceWitness : Type where
  dc : DC Unit Unit Unit RefState
  frame : DynFrame Unit Unit Bool RefState
  total : TotalNext frame.stepInt
  initial_dc : dc = stableDC
  dynamics : frame = stableDynFrame
  world_nontrivial : World.WldNontrivial stableWorld
  value_one : Value.normalized_V ({()} : Finset Unit) (fun _ : Unit => {()}) () = 1
  orbit : frame.conf .s1 = frame.update (frame.conf .s0) ∧
    frame.conf .s2 = frame.update (frame.conf .s1) ∧
    frame.conf .s2 = frame.update (frame.conf .s2)
  top_relations_empty : refPhi true Set.univ = ∅ ∧ refTheta true Set.univ = ∅

theorem stable_reference_model : Nonempty StableReferenceWitness := by
  refine ⟨{
    dc := stableDC
    frame := stableDynFrame
    total := stableTotalNext
    initial_dc := rfl
    dynamics := rfl
    world_nontrivial := stableWorld_nontrivial
    value_one := stableValue_one
    orbit := ?_
    top_relations_empty := by simp [refPhi, refTheta]
  }⟩
  constructor
  · exact stableDynFrame.h_int (stableTotalNext.next_internal .s0)
  constructor
  · exact stableDynFrame.h_int (stableTotalNext.next_internal .s1)
  · exact stableDynFrame.h_int (stableTotalNext.next_internal .s2)

end RefModel
end ERIEC
