import ERIEC.TemporalDC

namespace ERIEC

namespace TRMTopologyTransition

open OpenEvolution

/-!
Finite concrete witness for a TRM topology transition.

This is a reference semantics, not a proof that the Julia `TRMTopology`
implementation is definitionally equal to this model. It demonstrates that the
OpenDyn, viability, reproduction, heredity, M4, and richness contracts can be
inhabited simultaneously by one topology-changing system.
-/

/-- Before expansion: one fast, slow, and environmental state. -/
def baseSystem : OpenSystem where
  Fast := Unit
  Slow := Unit
  Env := Unit
  step := fun c => {c}

/-- After expansion: fast activity and slow topology state are both binary.
The inactive (`false`) slow state is stable; the active (`true`) state can
plasticly return to `false`. -/
def expandedSystem : OpenSystem where
  Fast := Bool
  Slow := Bool
  Env := Unit
  step := fun c =>
    if c.2.1 then {(c.1, (false, c.2.2))} else {c}

/-- Strict embedding of the base topology into the stable expanded state. -/
def topologyEmbedding : OpenSystem.Hom baseSystem expandedSystem where
  mapFast := fun _ => false
  mapSlow := fun _ => false
  mapEnv := _root_.id
  commutes := by
    intro c
    ext y
    simp [baseSystem, expandedSystem]

theorem topologyEmbedding_commutes (c : Config baseSystem) :
    Set.image topologyEmbedding.mapConfig (baseSystem.step c) =
      expandedSystem.step (topologyEmbedding.mapConfig c) :=
  topologyEmbedding.commutes' c

/-- The expanded system has a genuine slow-state-changing transition. -/
theorem expanded_adaptive : OpenSystem.Adaptive expandedSystem := by
  refine ⟨(false, (true, ())), (false, (false, ())), ?_, by simp⟩
  change (false, (false, ())) = (false, (false, ()))
  rfl

/-- The two occurrences already exhibited by `expanded_adaptive`.  They are
not clock constants: they name the source and target of that concrete slow
state transition while keeping repeated configurations distinguishable. -/
inductive RelaxationOccurrence where
  | plastic
  | stable

def relaxationState : RelaxationOccurrence → Config expandedSystem
  | .plastic => (false, (true, ()))
  | .stable => (false, (false, ()))

def relaxationNext : RelaxationOccurrence → RelaxationOccurrence → Prop
  | .plastic, .stable => True
  | _, _ => False

/-- Endogenous two-occurrence trace backed by the actual transition relation
of `expandedSystem`; no action or DC observation is fabricated here. -/
def relaxationTrace : TemporalDC.GeneratedTrace expandedSystem where
  Occurrence := RelaxationOccurrence
  state := relaxationState
  next := relaxationNext
  generated := by
    intro x y h
    cases x <;> cases y
    · exact False.elim h
    · change (false, (false, ())) = (false, (false, ()))
      rfl
    · exact False.elim h
    · exact False.elim h

theorem relaxation_immediate :
    relaxationTrace.next .plastic .stable :=
  trivial

theorem relaxation_generated :
    relaxationTrace.state .stable ∈
      expandedSystem.step (relaxationTrace.state .plastic) :=
  relaxationTrace.immediate_is_system_transition relaxation_immediate

theorem relaxation_precedes :
    relaxationTrace.clock.leq .plastic .stable :=
  relaxationTrace.immediate_is_time relaxation_immediate

/-- All states are viable in the finite reference model. Real TRM instances
must replace this with the actual DC/viability predicate. -/
def expandedViable : ViableSystem where
  toOpenSystem := expandedSystem
  viable := fun _ => True
  step_closed := by
    intro c c' hc hstep
    trivial

/-- Reproduction activates the new slow/topology component. -/
def reproduceExpanded (c : Config expandedSystem) : Set (Config expandedSystem) :=
  {(c.1, (true, c.2.2))}

def expandedReplicative : ReplicativeSystem where
  toViableSystem := expandedViable
  reproduce := reproduceExpanded
  offspring_viable := by
    intro parent child hp hc
    trivial

/-- Slow topology state is the hereditary marker in the reference model. -/
def expandedEvolutionary : EvolutionarySystem where
  toReplicativeSystem := expandedReplicative
  Heritage := Bool
  heritage := fun c => c.2.1
  hasVariation := by
    refine ⟨(false, (false, ())), (false, (true, ())), ?_, by simp⟩
    change (false, (true, ())) = (false, (true, ()))
    rfl
  populationStep := fun population => {population}

/-- Read-only structural richness: activation of the new slow component adds
one unit. -/
def richness (c : Config expandedSystem) : Nat :=
  match c.2.1 with
  | false => 0
  | true => 1

def observedParent : Config expandedSystem :=
  topologyEmbedding.mapConfig ((), ((), ()))

def observedChild : Config expandedSystem :=
  (false, (true, ()))

theorem observedChild_reproduced :
    observedChild ∈ expandedReplicative.reproduce observedParent := by
  change (false, (true, ())) = (false, (true, ()))
  rfl

theorem observedParent_viable : expandedViable.viable observedParent :=
  trivial

theorem observedChild_viable : expandedViable.viable observedChild :=
  expandedReplicative.offspring_viable
    observedParent_viable observedChild_reproduced

theorem observed_richer : richness observedParent < richness observedChild := by
  simp [richness, observedParent, observedChild, topologyEmbedding,
    OpenSystem.Hom.mapConfig]

theorem observed_heritage_changed :
    expandedEvolutionary.heritage observedChild ≠
      expandedEvolutionary.heritage observedParent := by
  simp [expandedEvolutionary, observedChild, observedParent, topologyEmbedding,
    OpenSystem.Hom.mapConfig]

/-- The reference seeking diagram has no arrows and hence no terminal target. -/
def desireDiagram : Body.SetPointDiagram Unit where
  reaches := fun _ _ => False

def trace (_selector : Unit) (c : Config expandedSystem) :
    MetaSelection.InternalTrace Unit Bool Nat Unit Bool where
  externalSetPoint := none
  nuPhi := c.2.1
  value := richness c
  desire := desireDiagram
  actionTrace := [c.1]

theorem trace_sigmaPure : MetaSelection.SigmaPure trace := by
  intro s₁ s₂ c
  rfl

theorem trace_m4 (c : Config expandedSystem) :
    MetaSelection.InternalTrace.M4 (trace () c) := by
  constructor
  · rfl
  · intro hterminal
    obtain ⟨target, hall⟩ := hterminal
    exact hall ()

/-- Topology mutation used by the observed reproduction event. -/
def topologyMutation (_selector : Unit) (c : Config expandedSystem) :
    Config expandedSystem :=
  (c.1, (true, c.2.2))

theorem topologyMutation_m4Safe :
    MetaSelection.M4SafeMutation trace topologyMutation := by
  intro s c hm4
  exact trace_m4 _

theorem observedParent_m4 :
    MetaSelection.InternalTrace.M4 (trace () observedParent) :=
  trace_m4 _

theorem observedChild_m4 :
    MetaSelection.InternalTrace.M4 (trace () observedChild) :=
  trace_m4 _

/-- One certificate proposition joining the concrete topology transition to
all contracts introduced for open evolution. -/
theorem observedTopologyTransition_certified :
    OpenSystem.Adaptive expandedSystem ∧
    expandedViable.viable observedParent ∧
    observedChild ∈ expandedReplicative.reproduce observedParent ∧
    expandedViable.viable observedChild ∧
    MetaSelection.InternalTrace.M4 (trace () observedParent) ∧
    MetaSelection.InternalTrace.M4 (trace () observedChild) ∧
    richness observedParent < richness observedChild ∧
    expandedEvolutionary.heritage observedChild ≠
      expandedEvolutionary.heritage observedParent :=
  ⟨expanded_adaptive,
    observedParent_viable,
    observedChild_reproduced,
    observedChild_viable,
    observedParent_m4,
    observedChild_m4,
    observed_richer,
    observed_heritage_changed⟩

end TRMTopologyTransition

end ERIEC
