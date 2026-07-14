import ERIEC.Gap
import ERIEC.Dynamics
import ERIEC.Invariance.External
import ERIEC.OpenDynamics
import ERIEC.Richness

namespace ERIEC
namespace NonDegenerateRecur

open OpenDynamics

/-- The multivalent action/environment kernel carried by every dynamic state. -/
def alphaRel (_ : Unit) : Set Bool :=
  Set.univ

def sigmaRel (_ : Bool) : Set Unit :=
  Set.univ

theorem gapUp : Gap.GapUp alphaRel sigmaRel () := by
  refine ⟨({true} : Set Bool), ?_, ?_⟩
  · simp [Adj.sigma_star, sigmaRel]
  · simp [Adj.sigma_star_induced, alphaRel]

theorem branch : Richness.Branch alphaRel () := by
  exact ⟨false, true, by simp [alphaRel], by simp [alphaRel], by decide⟩

theorem gapUp_iff_branch :
    Gap.GapUp alphaRel sigmaRel () ↔ Richness.Branch alphaRel () := by
  apply Gap.gapUp_iff_branch
  intro a e
  cases a
  cases e <;> simp [alphaRel, sigmaRel]

theorem gapUp_has_two_alpha :
    ∃ e₁ e₂, e₁ ∈ alphaRel () ∧ e₂ ∈ alphaRel () ∧ e₁ ≠ e₂ :=
  ⟨false, true, by simp [alphaRel]⟩

abbrev State := OpenDynamics.ReferenceModels.TwoState

open OpenDynamics.ReferenceModels.TwoState

/-- Internal dynamics of the recurrence body. -/
def stepInt : State → State → Prop
  | .a, .b => True
  | .b, .b => True
  | _, _ => False

/-- Every state carries the same multivalent intrinsic kernel. -/
def stateCore (_ : State) : Set Bool :=
  Set.univ

def stateEpsilon (_ : State) : Set Unit :=
  Set.univ

def phi (_ : Unit) (K : Set Bool) : Set Bool :=
  K

def theta (_ : Unit) (X : Set Unit) : Set Unit :=
  X

def drift (_ : Unit) (_ : Set Bool) : Unit :=
  ()

/-- The dynamic certification frame on which the open graph is built. -/
def dynFrame : Dynamics.DynFrame Bool Unit Unit State where
  phi := phi
  theta := theta
  drift := drift
  kappa := stateCore
  epsilon := stateEpsilon
  omega := fun _ ↦ ()
  stepInt := stepInt
  h_int := by
    intro s t h
    cases s <;> cases t <;>
      simp [stepInt, stateCore, stateEpsilon, phi, theta, drift,
        Dynamics.DynFrame.conf, Dynamics.upd] at h ⊢

/-- Typed repair coupling. It is available from every state, and in particular
contains the required return edge `b → a`. -/
def stepExt (_ : State) (t : State) : Prop :=
  t = .a

/-- Definition 17.16, made literal: internal edges are exactly `DynFrame.stepInt`
and coupling edges are exactly the external transition relation. -/
def inducedGraph : OpenGraph Unit where
  State := State
  step s kind t := match kind with
    | .internal => dynFrame.stepInt s t
    | .coupling _ => stepExt s t

theorem induced_internal_iff (s t : State) :
    inducedGraph.step s .internal t ↔ dynFrame.stepInt s t :=
  Iff.rfl

theorem induced_coupling_iff (s t : State) :
    inducedGraph.step s (.coupling ()) t ↔ stepExt s t :=
  Iff.rfl

def frame : OpenFrame Unit where
  graph := inducedGraph
  init := (· = .a)
  admissible := (· = .a)
  envelope := fun _ ↦ True
  admissible_subset_envelope := by simp
  fair := fun _ ↦ True

private theorem internal_edge_target_b {s t : State}
    (edge : inducedGraph.step s .internal t) : t = .b := by
  cases s <;> cases t <;> simp [inducedGraph, dynFrame, stepInt] at edge ⊢

private def internal_from_b_target_b :
    {s t : State} → (p : Path inducedGraph s t) →
      s = .b → p.Internal → t = .b
  | _, _, .nil _, hs, _ => hs
  | _, _, .cons (kind := kind) edge rest, _, hp => by
      have hkind : kind = EdgeKind.internal := hp.1
      subst kind
      exact internal_from_b_target_b rest (internal_edge_target_b edge) hp.2

private theorem internal_nonempty_target_b {s t : State}
    (p : Path inducedGraph s t) (hp : p.Internal) (hlen : 1 ≤ p.length) :
    t = .b :=
  match p with
  | .nil _ => by simp at hlen
  | .cons (kind := kind) edge rest => by
      have hkind : kind = EdgeKind.internal := hp.1
      subst kind
      exact internal_from_b_target_b rest (internal_edge_target_b edge) hp.2

theorem finiteInternalHorizon : frame.FiniteInternalHorizon := by
  intro s hs
  refine ⟨1, ?_⟩
  intro t p hp hlen ht
  have htB := internal_nonempty_target_b p hp hlen
  change t = .a at ht
  exact OpenDynamics.ReferenceModels.TwoState.noConfusion (htB.symm.trans ht)

def alternatingState : Nat → State
  | 0 => .a
  | n + 1 => match alternatingState n with
    | .a => .b
    | .b => .a

def alternatingKind (n : Nat) : EdgeKind Unit :=
  match alternatingState n with
  | .a => .internal
  | .b => .coupling ()

def alternatingExecution : Execution inducedGraph where
  state := alternatingState
  kind := alternatingKind
  edge := by
    intro n
    cases h : alternatingState n <;>
      simp [alternatingKind, alternatingState, h, inducedGraph, dynFrame,
        stepInt, stepExt]

theorem alternating_recurrent : frame.Recurrent alternatingExecution := by
  intro n
  cases h : alternatingState n with
  | a => exact ⟨n, le_rfl, h⟩
  | b =>
      refine ⟨n + 1, by omega, ?_⟩
      change alternatingState (n + 1) = .a
      simp [alternatingState, h]

theorem possibleLive : frame.PossibleLive :=
  ⟨alternatingExecution, rfl, alternating_recurrent⟩

theorem coupling_return : inducedGraph.step .b (.coupling ()) .a :=
  rfl

/-- Kernel compatibility used by E5. All states carry the same multivalent
kernel, so equality is the relevant finite-kernel isomorphism relation. -/
def CoreIso (K K' : Set Bool) : Prop :=
  K = K'

theorem all_cores_iso (s t : State) : CoreIso (stateCore s) (stateCore t) :=
  rfl

theorem e5 : Invariance.E5 stepExt stateCore CoreIso := by
  constructor
  intro s s' t _hIso hExt
  refine ⟨.a, rfl, ?_⟩
  exact all_cores_iso t .a

/-- The integrated §23.4 witness: every field refers to the same dynamic frame
and its definitionally induced open graph. -/
structure Witness where
  gapUp : Gap.GapUp alphaRel sigmaRel ()
  branch : Richness.Branch alphaRel ()
  graphInducedInternal : ∀ s t,
    inducedGraph.step s .internal t ↔ dynFrame.stepInt s t
  graphInducedCoupling : ∀ s t,
    inducedGraph.step s (.coupling ()) t ↔ stepExt s t
  finiteInternalHorizon : frame.FiniteInternalHorizon
  possibleLive : frame.PossibleLive
  couplingReturn : inducedGraph.step .b (.coupling ()) .a
  endpointCoresIso : CoreIso (stateCore .b) (stateCore .a)
  externalTransport : Invariance.E5 stepExt stateCore CoreIso

def witness : Witness where
  gapUp := gapUp
  branch := branch
  graphInducedInternal := induced_internal_iff
  graphInducedCoupling := induced_coupling_iff
  finiteInternalHorizon := finiteInternalHorizon
  possibleLive := possibleLive
  couplingReturn := coupling_return
  endpointCoresIso := all_cores_iso .b .a
  externalTransport := e5

abbrev FullWitness := Witness

def fullWitness : FullWitness :=
  witness

theorem fullWitness_has_gapUp : fullWitness.gapUp = gapUp :=
  rfl

theorem fullWitness_has_branch : Richness.Branch alphaRel () :=
  fullWitness.branch

theorem fullWitness_has_recur :
    frame.FiniteInternalHorizon ∧ frame.PossibleLive :=
  ⟨fullWitness.finiteInternalHorizon, fullWitness.possibleLive⟩

end NonDegenerateRecur
end ERIEC
