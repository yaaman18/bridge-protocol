import ERIEC.OpenDynamics
import ERIEC.MetaSelection

namespace ERIEC

namespace Audit

open OpenDynamics

universe u v w x y

variable {Port : Type u} {G : OpenGraph.{u, v} Port}
  {r s t : G.State}

/-- §18.1: every edge in a path has the specified provenance label. -/
def UsesOnly : {r s : G.State} → EdgeKind Port → Path G r s → Prop
  | _, _, _, .nil _ => True
  | _, _, kind, .cons (kind := actual) _ rest =>
      actual = kind ∧ UsesOnly kind rest

theorem usesOnly_append {kind : EdgeKind Port}
    {p : Path G r s} {q : Path G s t}
    (hp : UsesOnly kind p) (hq : UsesOnly kind q) :
    UsesOnly kind (p.append q) := by
  induction p with
  | nil => exact hq
  | cons edge rest ih =>
      change _ ∧ _ at hp
      exact ⟨hp.1, ih hp.2 hq⟩

/-- §18.1: a label-preserving path simulation between open graphs. -/
structure Simulation {Port : Type u}
    (G : OpenGraph.{u, v} Port) (H : OpenGraph.{u, w} Port) where
  mapState : G.State → H.State
  maps : ∀ {s t kind}, G.step s kind t →
    ∃ p : Path H (mapState s) (mapState t), UsesOnly kind p

namespace Simulation

variable {Port : Type u}
  {G : OpenGraph.{u, v} Port}
  {H : OpenGraph.{u, w} Port}
  {K : OpenGraph.{u, x} Port}

noncomputable def edgePath (f : Simulation G H) {s t kind}
    (edge : G.step s kind t) : Path H (f.mapState s) (f.mapState t) :=
  Classical.choose (f.maps edge)

theorem edgePath_usesOnly (f : Simulation G H) {s t kind}
    (edge : G.step s kind t) : UsesOnly kind (f.edgePath edge) :=
  Classical.choose_spec (f.maps edge)

/-- A simulation maps every free source path to a free target path. -/
noncomputable def mapPath (f : Simulation G H) :
    {s t : G.State} → Path G s t → Path H (f.mapState s) (f.mapState t)
  | _, _, .nil s => .nil (f.mapState s)
  | _, _, .cons edge rest => (f.edgePath edge).append (f.mapPath rest)

theorem mapPath_usesOnly (f : Simulation G H) {s t : G.State}
    {kind : EdgeKind Port} {p : Path G s t} (hp : UsesOnly kind p) :
    UsesOnly kind (f.mapPath p) := by
  induction p with
  | nil => change True; trivial
  | @cons _ _ _ actual edge rest ih =>
      change actual = kind ∧ UsesOnly kind rest at hp
      exact usesOnly_append
        (by simpa [hp.1] using f.edgePath_usesOnly edge)
        (ih hp.2)

noncomputable def id (G : OpenGraph.{u, v} Port) : Simulation G G where
  mapState := _root_.id
  maps := by
    intro s t kind edge
    refine ⟨Path.single edge, ?_⟩
    exact ⟨rfl, trivial⟩

noncomputable def comp (f : Simulation G H) (g : Simulation H K) :
    Simulation G K where
  mapState := g.mapState ∘ f.mapState
  maps := by
    intro s t kind edge
    refine ⟨g.mapPath (f.edgePath edge), ?_⟩
    exact g.mapPath_usesOnly (f.edgePath_usesOnly edge)

@[ext] theorem ext {f g : Simulation G H} (h : f.mapState = g.mapState) :
    f = g := by
  cases f
  cases g
  cases h
  rfl

theorem id_comp (f : Simulation G H) : comp (id G) f = f := by
  apply ext
  rfl

theorem comp_id (f : Simulation G H) : comp f (id H) = f := by
  apply ext
  rfl

theorem assoc (f : Simulation G H) (g : Simulation H K)
    {L : OpenGraph.{u, y} Port} (h : Simulation K L) :
    comp (comp f g) h = comp f (comp g h) := by
  apply ext
  rfl

end Simulation

/-- R-4 repaired simulation used by audit certificates. Every source edge
stores its target path and its label-preservation proof directly. The legacy
`Simulation` category remains below only as a compatibility layer. -/
structure CertifiedSimulation {Port : Type u}
    (G : OpenGraph.{u, v} Port) (H : OpenGraph.{u, w} Port) where
  mapState : G.State → H.State
  mapEdge : ∀ {s t kind}, G.step s kind t →
    {p : Path H (mapState s) (mapState t) // UsesOnly kind p}

namespace CertifiedSimulation

variable {Port : Type u}
  {G : OpenGraph.{u, v} Port}
  {H : OpenGraph.{u, w} Port}

def mapPath (f : CertifiedSimulation G H) :
    {s t : G.State} → Path G s t → Path H (f.mapState s) (f.mapState t)
  | _, _, .nil s => .nil (f.mapState s)
  | _, _, .cons edge rest => (f.mapEdge edge).1.append (f.mapPath rest)

theorem mapPath_usesOnly (f : CertifiedSimulation G H) {s t : G.State}
    {kind : EdgeKind Port} {p : Path G s t} (hp : UsesOnly kind p) :
    UsesOnly kind (f.mapPath p) := by
  induction p with
  | nil =>
      change True
      trivial
  | @cons _ _ _ actual edge rest ih =>
      change actual = kind ∧ UsesOnly kind rest at hp
      exact usesOnly_append
        (by simpa [hp.1] using (f.mapEdge edge).2)
        (ih hp.2)

def id (G : OpenGraph.{u, v} Port) : CertifiedSimulation G G where
  mapState := _root_.id
  mapEdge := by
    intro s t kind edge
    exact ⟨Path.single edge, ⟨rfl, trivial⟩⟩

end CertifiedSimulation

/-! Theorem 18.2: open graphs and label-preserving simulations form a category. -/

section OpenSimCategory

open CategoryTheory

variable (Port : Type u)

noncomputable instance openSimCategory : CategoryTheory.Category (OpenGraph.{u, v} Port) where
  Hom := Simulation
  id := Simulation.id
  comp := Simulation.comp
  id_comp := Simulation.id_comp
  comp_id := Simulation.comp_id
  assoc := fun f g h => Simulation.assoc f g h

end OpenSimCategory

/-- §18.2: an implementation-to-model abstraction certificate.
Fingerprint, scope notes, and assumptions remain explicit certificate data. -/
structure AuditMap {Port : Type u}
    (I : OpenFrame.{u, v} Port) (M : OpenFrame.{u, w} Port)
    (Fingerprint Assumption : Type x) where
  simulation : CertifiedSimulation I.graph M.graph
  initPres : ∀ {s}, I.init s → M.init (simulation.mapState s)
  scopeSurj : ∀ {m}, M.ReachInit m →
    ∃ i, I.ReachInit i ∧ simulation.mapState i = m
  fingerprint : Fingerprint
  assumptions : List Assumption

/-- Theorem 18.3: absence of an initial-component terminal target is sound
under a path simulation that preserves initial states and covers audit scope. -/
theorem noTerminalInit_sound {Port : Type u}
    {I : OpenFrame.{u, v} Port} {M : OpenFrame.{u, w} Port}
    {Fingerprint Assumption : Type x}
    (audit : AuditMap I M Fingerprint Assumption)
    (hM : M.NoTerminalInit) : I.NoTerminalInit := by
  intro hI
  apply hM
  obtain ⟨target, htargetReach, hterminal⟩ := hI
  refine ⟨audit.simulation.mapState target, ?_, ?_⟩
  · obtain ⟨source, hsourceInit, ⟨path⟩⟩ := htargetReach
    exact ⟨audit.simulation.mapState source,
      audit.initPres hsourceInit,
      ⟨audit.simulation.mapPath path⟩⟩
  · intro m hm
    obtain ⟨i, hiReach, hiMap⟩ := audit.scopeSurj hm
    obtain ⟨path⟩ := hterminal i hiReach
    have mapped := audit.simulation.mapPath path
    rw [hiMap] at mapped
    exact ⟨mapped⟩

/-! §18.3: provenance-typed noninterference and endogenous recovery. -/

inductive PortClass where
  | resource
  | signal
  | goal
  | selector
  deriving DecidableEq, Repr

def GoalNI {Goal Input Output : Type*}
    (observe : Goal → Input → Output) : Prop :=
  ∀ g₁ g₂ i, observe g₁ i = observe g₂ i

def InternalFactor {Goal Input View Output : Type*}
    (internalView : Input → View)
    (observe : Goal → Input → Output) : Prop :=
  ∃ decide : View → Output, ∀ g i, observe g i = decide (internalView i)

/-- The provenance graph itself is implementation-specific; the formal core
requires its safety proposition as a separate proof field. -/
structure EndogenousRecovery {Port : Type u}
    (O : OpenFrame.{u, v} Port)
    {Goal Input View Decision : Type*}
    (internalView : Input → View)
    (recoveryObserve : Goal → Input → Decision)
    (ProvenanceSafe : Prop) : Prop where
  recoverable : O.Recoverable
  internalFactor : InternalFactor internalView recoveryObserve
  goalNI : GoalNI recoveryObserve
  provenanceSafe : ProvenanceSafe

/-- Theorem 18.7, first half: goal noninterference transports every predicate,
in particular M4, across changes of the external goal state. -/
theorem goalNI_preserves_predicate {Goal Input Output : Type*}
    (observe : Goal → Input → Output)
    (P : Output → Prop)
    (hNI : GoalNI observe)
    (g₁ g₂ : Goal) (i : Input) :
    P (observe g₁ i) ↔ P (observe g₂ i) := by
  rw [hNI g₁ g₂ i]

/-- §18.8 result classification for audit certificates. -/
inductive ResultKind where
  | proved
  | refuted
  | bounded
  | observed
  | unknown
  deriving DecidableEq, Repr

structure Certificate
    (Claim Fingerprint Version Dependency Checker TrustBoundary Scope : Type*) where
  claim : Claim
  subjectFingerprint : Fingerprint
  abstractionVersion : Version
  dependencies : List Dependency
  checker : Checker
  trustBoundary : TrustBoundary
  scope : Scope
  result : ResultKind

end Audit

end ERIEC
