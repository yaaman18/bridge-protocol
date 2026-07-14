import ERIEC.Audit
import Mathlib.CategoryTheory.Functor.Basic

namespace ERIEC

namespace OpenSimC

open OpenDynamics

universe u v w x

/-- §23.5': a constructive, evidence-carrying open simulation.

Unlike `Audit.Simulation`, every source edge is mapped to a concrete target
path together with the proof that the path uses only the source edge kind.
-/
structure Hom {Port : Type u}
    (G : OpenGraph.{u, v} Port) (H : OpenGraph.{u, w} Port) where
  mapState : G.State → H.State
  mapEdge : ∀ {s t kind}, G.step s kind t →
    {p : Path H (mapState s) (mapState t) // Audit.UsesOnly kind p}

namespace Hom

variable {Port : Type u}
  {G : OpenGraph.{u, v} Port}
  {H : OpenGraph.{u, w} Port}
  {K : OpenGraph.{u, x} Port}

/-- Erase constructive path witnesses to the existing propositional simulation. -/
def erase (f : Hom G H) : Audit.Simulation G H where
  mapState := f.mapState
  maps := by
    intro s t kind edge
    exact ⟨(f.mapEdge edge).1, (f.mapEdge edge).2⟩

theorem erase_mapState (f : Hom G H) :
    (erase f).mapState = f.mapState :=
  rfl

theorem erase_maps_witness (f : Hom G H) {s t : G.State} {kind : EdgeKind Port}
    (edge : G.step s kind t) :
    ∃ p : Path H (f.mapState s) (f.mapState t), Audit.UsesOnly kind p :=
  (erase f).maps edge

/-- R-4 migration: constructive open simulations are the direct certificate
payload accepted by `Audit.AuditMap`. -/
def certify (f : Hom G H) : Audit.CertifiedSimulation G H where
  mapState := f.mapState
  mapEdge := f.mapEdge

/-- The constructive identity simulation sends each edge to the one-edge path. -/
def id (G : OpenGraph.{u, v} Port) : Hom G G where
  mapState := _root_.id
  mapEdge := by
    intro s t kind edge
    exact ⟨Path.single edge, ⟨rfl, trivial⟩⟩

/-- A constructive simulation maps free paths by concatenating edge witnesses. -/
def mapPath (f : Hom G H) :
    {s t : G.State} → Path G s t → Path H (f.mapState s) (f.mapState t)
  | _, _, .nil s => .nil (f.mapState s)
  | _, _, .cons edge rest => (f.mapEdge edge).1.append (f.mapPath rest)

theorem mapPath_usesOnly (f : Hom G H) {s t : G.State}
    {kind : EdgeKind Port} {p : Path G s t} (hp : Audit.UsesOnly kind p) :
    Audit.UsesOnly kind (f.mapPath p) := by
  induction p with
  | nil =>
      change True
      trivial
  | @cons _ _ _ actual edge rest ih =>
      change actual = kind ∧ Audit.UsesOnly kind rest at hp
      exact Audit.usesOnly_append
        (by simpa [hp.1] using (f.mapEdge edge).2)
        (ih hp.2)

@[simp] theorem mapPath_nil (f : Hom G H) (s : G.State) :
    f.mapPath (.nil s) = .nil (f.mapState s) :=
  rfl

theorem mapPath_append (f : Hom G H) {r s t : G.State}
    (p : Path G r s) (q : Path G s t) :
    f.mapPath (p.append q) = (f.mapPath p).append (f.mapPath q) := by
  induction p with
  | nil =>
      rfl
  | cons edge rest ih =>
      simp [mapPath, Path.append, ih, Path.append_assoc]

theorem mapPath_single (f : Hom G H) {s t : G.State} {kind : EdgeKind Port}
    (edge : G.step s kind t) :
    f.mapPath (Path.single edge) = (f.mapEdge edge).1 := by
  simp [Path.single, mapPath]

theorem mapPath_id {Port : Type u} {G : OpenGraph.{u, v} Port}
    {s t : G.State} (p : Path G s t) :
    (id G).mapPath p = p := by
  induction p with
  | nil =>
      rfl
  | cons edge rest ih =>
      change (Path.single edge).append ((id G).mapPath rest) = Path.cons edge rest
      rw [ih]
      rfl

/-- Composition concatenates the concrete target paths supplied by the codomain map. -/
def comp (f : Hom G H) (g : Hom H K) : Hom G K where
  mapState := g.mapState ∘ f.mapState
  mapEdge := by
    intro s t kind edge
    exact ⟨g.mapPath (f.mapEdge edge).1, g.mapPath_usesOnly (f.mapEdge edge).2⟩

theorem mapPath_comp (f : Hom G H) (g : Hom H K) {s t : G.State}
    (p : Path G s t) :
    (comp f g).mapPath p = g.mapPath (f.mapPath p) := by
  induction p with
  | nil =>
      rfl
  | cons edge rest ih =>
      simp only [mapPath, comp, mapPath_append]
      exact congrArg (fun q => (g.mapPath (f.mapEdge edge).1).append q) ih

theorem mapPath_id_comp (f : Hom G H) {s t : G.State}
    (p : Path G s t) :
    (comp (id G) f).mapPath p = f.mapPath p := by
  rw [mapPath_comp, mapPath_id]
  rfl

theorem mapPath_comp_id (f : Hom G H) {s t : G.State}
    (p : Path G s t) :
    (comp f (id H)).mapPath p = f.mapPath p := by
  rw [mapPath_comp, mapPath_id]

/-- Two constructive simulations are equal when their state maps and every
carried target path agree. -/
@[ext] theorem ext {f g : Hom G H} (hState : f.mapState = g.mapState)
    (hEdge : ∀ {s t kind} (edge : G.step s kind t),
      HEq (f.mapEdge edge).1 (g.mapEdge edge).1) : f = g := by
  cases f with
  | mk fState fEdge =>
      cases g with
      | mk gState gEdge =>
          dsimp at hState
          subst gState
          congr
          funext s t kind edge
          apply Subtype.ext
          exact eq_of_heq (hEdge edge)

theorem id_comp (f : Hom G H) : comp (id G) f = f := by
  apply ext
  · rfl
  · intro s t kind edge
    exact heq_of_eq (mapPath_single f edge)

theorem comp_id (f : Hom G H) : comp f (id H) = f := by
  apply ext
  · rfl
  · intro s t kind edge
    exact heq_of_eq (mapPath_id (f.mapEdge edge).1)

theorem assoc (f : Hom G H) (g : Hom H K)
    {L : OpenGraph.{u, x} Port} (h : Hom K L) :
    comp (comp f g) h = comp f (comp g h) := by
  apply ext
  · rfl
  · intro s t kind edge
    exact heq_of_eq (mapPath_comp g h (f.mapEdge edge).1).symm

theorem erase_id (G : OpenGraph.{u, v} Port) :
    erase (id G) = Audit.Simulation.id G := by
  apply Audit.Simulation.ext
  rfl

theorem erase_comp (f : Hom G H) (g : Hom H K) :
    erase (comp f g) = Audit.Simulation.comp (erase f) (erase g) := by
  apply Audit.Simulation.ext
  rfl

end Hom

/-- Object wrapper separating the constructive simulation category from the
legacy category instance on bare `OpenGraph` values. -/
structure Object (Port : Type u) where
  graph : OpenGraph.{u, v} Port

namespace Object

open CategoryTheory

instance category (Port : Type u) : CategoryTheory.Category (Object.{u, v} Port) where
  Hom X Y := Hom X.graph Y.graph
  id X := Hom.id X.graph
  comp f g := Hom.comp f g
  id_comp := Hom.id_comp
  comp_id := Hom.comp_id
  assoc := fun f g h ↦ Hom.assoc f g h

end Object

open CategoryTheory

/-- §23.5′: erasure of carried paths is a functor to the legacy open
simulation category. -/
noncomputable def eraseFunctor (Port : Type u) :
    Object.{u, v} Port ⥤ OpenGraph.{u, v} Port where
  obj X := X.graph
  map f := Hom.erase f
  map_id X := Hom.erase_id X.graph
  map_comp f g := Hom.erase_comp f g

/-- The identity audit map for a formal open frame, using no extra assumptions. -/
def identityAuditMap {Port : Type u} (O : OpenFrame.{u, v} Port) :
    Audit.AuditMap O O (OpenFrame.{u, v} Port) (OpenFrame.{u, v} Port) where
  simulation := Hom.certify (Hom.id O.graph)
  initPres := by
    intro s hs
    exact hs
  scopeSurj := by
    intro m hm
    exact ⟨m, hm, rfl⟩
  fingerprint := O
  assumptions := []

theorem identityAuditMap_simulation {Port : Type u} (O : OpenFrame.{u, v} Port) :
    (identityAuditMap O).simulation = Audit.CertifiedSimulation.id O.graph :=
  rfl

theorem identityAuditMap_initPres {Port : Type u} (O : OpenFrame.{u, v} Port)
    {s : O.graph.State} (hs : O.init s) :
    O.init ((identityAuditMap O).simulation.mapState s) :=
  hs

theorem identityAuditMap_scopeSurj {Port : Type u} (O : OpenFrame.{u, v} Port)
    {m : O.graph.State} (hm : O.ReachInit m) :
    ∃ i, O.ReachInit i ∧ (identityAuditMap O).simulation.mapState i = m :=
  ⟨m, hm, rfl⟩

theorem identityAuditMap_noAssumptions {Port : Type u} (O : OpenFrame.{u, v} Port) :
    (identityAuditMap O).assumptions = [] :=
  rfl

end OpenSimC

end ERIEC
