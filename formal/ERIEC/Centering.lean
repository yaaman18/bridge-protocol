import ERIEC.Invariance

namespace ERIEC

namespace Centering

universe u

/-- §25.1: strength tags for invariant predicate families. -/
inductive Strength where
  | statK
  | statF
  | dyn
  | dynObs
  | dynLab
  | dynRep
  | dynLabRep
deriving DecidableEq, Repr

/-- §25.2: a strength-indexed compatible isomorphism.

The common static core is `Invariance.KIso`. Higher-strength compatibilities
are carried as fields on later refinements, rather than by changing `KIso`.
-/
structure CompatibleIso (τ : Strength)
    {A E C S A' E' C' S' W : Type u}
    (F : Invariance.StaticFrame A E C S W)
    (F' : Invariance.StaticFrame A' E' C' S' W) where
  static : Invariance.KIso F F'

/-- Forget any stronger compatibility data down to the static `𝔽` level.
At present `CompatibleIso` stores only the shared static core; future stronger
fields can be forgotten here without changing users of static invariance. -/
def CompatibleIso.toStatF {τ : Strength}
    {A E C S A' E' C' S' W : Type u}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : CompatibleIso τ F F') : CompatibleIso Strength.statF F F' where
  static := h.static

/-- Static `𝔎` forgetful projection, separated from `toStatF` to avoid
assuming an unformalized global strength lattice. -/
def CompatibleIso.toStatK {τ : Strength}
    {A E C S A' E' C' S' W : Type u}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : CompatibleIso τ F F') : CompatibleIso Strength.statK F F' where
  static := h.static

/-- §25.1: an invariant predicate family over the `A × S` carrier. -/
structure InvariantFamily (τ : Strength) where
  Pred : {A E C S W : Type u} →
    Invariance.StaticFrame A E C S W → A → S → Prop
  invariant :
    ∀ {A E C S A' E' C' S' W : Type u}
      {F : Invariance.StaticFrame A E C S W}
      {F' : Invariance.StaticFrame A' E' C' S' W}
      (h : CompatibleIso τ F F') (m : A) (s : S),
        Pred F m s ↔ Pred F' (h.static.hA m) (h.static.hS s)

/-- The analogous invariant-family schema for predicates over `E × S`. -/
structure InvariantFamilyE (τ : Strength) where
  Pred : {A E C S W : Type u} →
    Invariance.StaticFrame A E C S W → E → S → Prop
  invariant :
    ∀ {A E C S A' E' C' S' W : Type u}
      {F : Invariance.StaticFrame A E C S W}
      {F' : Invariance.StaticFrame A' E' C' S' W}
      (h : CompatibleIso τ F F') (e : E) (s : S),
        Pred F e s ↔ Pred F' (h.static.hE e) (h.static.hS s)

/-- The analogous invariant-family schema for predicates over `C × S`. -/
structure InvariantFamilyC (τ : Strength) where
  Pred : {A E C S W : Type u} →
    Invariance.StaticFrame A E C S W → C → S → Prop
  invariant :
    ∀ {A E C S A' E' C' S' W : Type u}
      {F : Invariance.StaticFrame A E C S W}
      {F' : Invariance.StaticFrame A' E' C' S' W}
      (h : CompatibleIso τ F F') (c : C) (s : S),
        Pred F c s ↔ Pred F' (h.static.hC c) (h.static.hS s)

/-- §25.2: a center symmetry exchanging `m` with `m'` in a single frame. -/
structure CenterSymmetry (τ : Strength)
    {A E C S W : Type u} (F : Invariance.StaticFrame A E C S W)
    (m m' : A) where
  iso : CompatibleIso τ F F
  maps_center : iso.static.hA m = m'

/-- A center symmetry that also fixes a specified state. -/
structure FixedCenterSymmetry (τ : Strength)
    {A E C S W : Type u} (F : Invariance.StaticFrame A E C S W)
    (m m' : A) (s : S) extends CenterSymmetry τ F m m' where
  fixes_state : toCenterSymmetry.iso.static.hS s = s

def CenterSymmetry.toStatF {τ : Strength}
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    {m m' : A} (φ : CenterSymmetry τ F m m') :
    CenterSymmetry Strength.statF F m m' where
  iso := φ.iso.toStatF
  maps_center := φ.maps_center

def FixedCenterSymmetry.toStatF {τ : Strength}
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    {m m' : A} {s : S} (φ : FixedCenterSymmetry τ F m m' s) :
    FixedCenterSymmetry Strength.statF F m m' s where
  iso := φ.toCenterSymmetry.iso.toStatF
  maps_center := φ.maps_center
  fixes_state := φ.fixes_state

/-- §25.3: indistinguishability is direct specialization of invariance. -/
def indist_specialize {τ : Strength}
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    (Pred : InvariantFamily τ) {m m' : A}
    (φ : CenterSymmetry τ F m m') (s : S) :
    Pred.Pred F m s ↔ Pred.Pred F m' (φ.iso.static.hS s) := by
  simpa [φ.maps_center] using Pred.invariant φ.iso m s

/-- §25.3 fixed-state specialization. -/
def indist_fixed {τ : Strength}
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    (Pred : InvariantFamily τ) {m m' : A} {s : S}
    (φ : FixedCenterSymmetry τ F m m' s) :
    Pred.Pred F m s ↔ Pred.Pred F m' s := by
  simpa [φ.maps_center, φ.fixes_state] using
    Pred.invariant φ.toCenterSymmetry.iso m s

/-- Direct specialization of an `E × S` invariant family. -/
def invariantE_specialize {τ : Strength}
    {A E C S A' E' C' S' W : Type u}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (Pred : InvariantFamilyE τ) (h : CompatibleIso τ F F') (e : E) (s : S) :
    Pred.Pred F e s ↔ Pred.Pred F' (h.static.hE e) (h.static.hS s) :=
  Pred.invariant h e s

/-- Direct specialization of a `C × S` invariant family. -/
def invariantC_specialize {τ : Strength}
    {A E C S A' E' C' S' W : Type u}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (Pred : InvariantFamilyC τ) (h : CompatibleIso τ F F') (c : C) (s : S) :
    Pred.Pred F c s ↔ Pred.Pred F' (h.static.hC c) (h.static.hS s) :=
  Pred.invariant h c s

def invariant_fixed {τ : Strength}
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    (Pred : InvariantFamily τ) (h : CompatibleIso τ F F)
    {m m' : A} {s : S}
    (hm : h.static.hA m = m') (hs : h.static.hS s = s) :
    Pred.Pred F m s ↔ Pred.Pred F m' s := by
  simpa [hm, hs] using Pred.invariant h m s

def invariantE_fixed {τ : Strength}
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    (Pred : InvariantFamilyE τ) (h : CompatibleIso τ F F)
    {e e' : E} {s : S}
    (he : h.static.hE e = e') (hs : h.static.hS s = s) :
    Pred.Pred F e s ↔ Pred.Pred F e' s := by
  simpa [he, hs] using Pred.invariant h e s

def invariantC_fixed {τ : Strength}
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    (Pred : InvariantFamilyC τ) (h : CompatibleIso τ F F)
    {c c' : C} {s : S}
    (hc : h.static.hC c = c') (hs : h.static.hS s = s) :
    Pred.Pred F c s ↔ Pred.Pred F c' s := by
  simpa [hc, hs] using Pred.invariant h c s

def andFamilyE {τ : Strength} (P Q : InvariantFamilyE τ) : InvariantFamilyE τ where
  Pred := fun F e s => P.Pred F e s ∧ Q.Pred F e s
  invariant := by
    intro A E C S A' E' C' S' W F F' h e s
    exact Iff.and (P.invariant h e s) (Q.invariant h e s)

def orFamilyE {τ : Strength} (P Q : InvariantFamilyE τ) : InvariantFamilyE τ where
  Pred := fun F e s => P.Pred F e s ∨ Q.Pred F e s
  invariant := by
    intro A E C S A' E' C' S' W F F' h e s
    exact Iff.or (P.invariant h e s) (Q.invariant h e s)

def notFamilyE {τ : Strength} (P : InvariantFamilyE τ) : InvariantFamilyE τ where
  Pred := fun F e s => ¬ P.Pred F e s
  invariant := by
    intro A E C S A' E' C' S' W F F' h e s
    exact Iff.not (P.invariant h e s)

def impFamilyE {τ : Strength} (P Q : InvariantFamilyE τ) : InvariantFamilyE τ where
  Pred := fun F e s => P.Pred F e s → Q.Pred F e s
  invariant := by
    intro A E C S A' E' C' S' W F F' h e s
    exact Iff.imp (P.invariant h e s) (Q.invariant h e s)

def iffFamilyE {τ : Strength} (P Q : InvariantFamilyE τ) : InvariantFamilyE τ where
  Pred := fun F e s => P.Pred F e s ↔ Q.Pred F e s
  invariant := by
    intro A E C S A' E' C' S' W F F' h e s
    exact Iff.iff (P.invariant h e s) (Q.invariant h e s)

def trueFamilyE (τ : Strength) : InvariantFamilyE τ where
  Pred := fun _ _ _ => True
  invariant := by
    intro A E C S A' E' C' S' W F F' h e s
    simp

def falseFamilyE (τ : Strength) : InvariantFamilyE τ where
  Pred := fun _ _ _ => False
  invariant := by
    intro A E C S A' E' C' S' W F F' h e s
    simp

def andFamilyC {τ : Strength} (P Q : InvariantFamilyC τ) : InvariantFamilyC τ where
  Pred := fun F c s => P.Pred F c s ∧ Q.Pred F c s
  invariant := by
    intro A E C S A' E' C' S' W F F' h c s
    exact Iff.and (P.invariant h c s) (Q.invariant h c s)

def orFamilyC {τ : Strength} (P Q : InvariantFamilyC τ) : InvariantFamilyC τ where
  Pred := fun F c s => P.Pred F c s ∨ Q.Pred F c s
  invariant := by
    intro A E C S A' E' C' S' W F F' h c s
    exact Iff.or (P.invariant h c s) (Q.invariant h c s)

def notFamilyC {τ : Strength} (P : InvariantFamilyC τ) : InvariantFamilyC τ where
  Pred := fun F c s => ¬ P.Pred F c s
  invariant := by
    intro A E C S A' E' C' S' W F F' h c s
    exact Iff.not (P.invariant h c s)

def impFamilyC {τ : Strength} (P Q : InvariantFamilyC τ) : InvariantFamilyC τ where
  Pred := fun F c s => P.Pred F c s → Q.Pred F c s
  invariant := by
    intro A E C S A' E' C' S' W F F' h c s
    exact Iff.imp (P.invariant h c s) (Q.invariant h c s)

def iffFamilyC {τ : Strength} (P Q : InvariantFamilyC τ) : InvariantFamilyC τ where
  Pred := fun F c s => P.Pred F c s ↔ Q.Pred F c s
  invariant := by
    intro A E C S A' E' C' S' W F F' h c s
    exact Iff.iff (P.invariant h c s) (Q.invariant h c s)

def trueFamilyC (τ : Strength) : InvariantFamilyC τ where
  Pred := fun _ _ _ => True
  invariant := by
    intro A E C S A' E' C' S' W F F' h c s
    simp

def falseFamilyC (τ : Strength) : InvariantFamilyC τ where
  Pred := fun _ _ _ => False
  invariant := by
    intro A E C S A' E' C' S' W F F' h c s
    simp

/-- Invariant predicate families are closed under conjunction. -/
def andFamily {τ : Strength} (P Q : InvariantFamily τ) : InvariantFamily τ where
  Pred := fun F m s => P.Pred F m s ∧ Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact Iff.and (P.invariant h m s) (Q.invariant h m s)

/-- Invariant predicate families are closed under disjunction. -/
def orFamily {τ : Strength} (P Q : InvariantFamily τ) : InvariantFamily τ where
  Pred := fun F m s => P.Pred F m s ∨ Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact Iff.or (P.invariant h m s) (Q.invariant h m s)

/-- Invariant predicate families are closed under negation. -/
def notFamily {τ : Strength} (P : InvariantFamily τ) : InvariantFamily τ where
  Pred := fun F m s => ¬ P.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact Iff.not (P.invariant h m s)

/-- Invariant predicate families are closed under implication. -/
def impFamily {τ : Strength} (P Q : InvariantFamily τ) : InvariantFamily τ where
  Pred := fun F m s => P.Pred F m s → Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact Iff.imp (P.invariant h m s) (Q.invariant h m s)

/-- Invariant predicate families are closed under logical equivalence. -/
def iffFamily {τ : Strength} (P Q : InvariantFamily τ) : InvariantFamily τ where
  Pred := fun F m s => P.Pred F m s ↔ Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact Iff.iff (P.invariant h m s) (Q.invariant h m s)

/-- A trivially true invariant predicate family. -/
def trueFamily (τ : Strength) : InvariantFamily τ where
  Pred := fun _ _ _ => True
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    simp

/-- A trivially false invariant predicate family. -/
def falseFamily (τ : Strength) : InvariantFamily τ where
  Pred := fun _ _ _ => False
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    simp

/-- §25.4 baseline: the state-indexed DC clauses form a static-invariant
predicate family when regarded as a predicate over `A × S`. -/
def dcAtFamily : InvariantFamily Strength.statF where
  Pred := fun F _ s => F.DCAt s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact Invariance.static_DC_bisim h.static s

/-- Fixed-center specialization for the DC predicate family. -/
theorem dcAt_horizontal_wall
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    {m m' : A} {s : S}
    (φ : FixedCenterSymmetry Strength.statF F m m' s) :
    F.DCAt s ↔ F.DCAt s :=
  indist_fixed dcAtFamily φ

/-- v5.2 §25.5 public name for the horizontal-wall specialization currently
implemented for the certified static DC predicate family. -/
theorem horizontal_wall
    {A E C S W : Type u} {F : Invariance.StaticFrame A E C S W}
    {m m' : A} {s : S}
    (φ : FixedCenterSymmetry Strength.statF F m m' s) :
    F.DCAt s ↔ F.DCAt s :=
  dcAt_horizontal_wall φ

end Centering

end ERIEC
