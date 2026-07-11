namespace ERIEC

namespace Graded

universe u v x

/-!
Minimal graded layer.

This file deliberately fixes only the small proof surface needed by the
current implementation: a thin category is represented by a reflexive and
transitive relation, and a presheaf is represented by fibers with restriction
maps satisfying identity and composition laws.
-/

structure ThinCategory (W : Type u) where
  leq : W → W → Prop
  refl : ∀ w, leq w w
  trans : ∀ {u v w}, leq u v → leq v w → leq u w

structure Presheaf {W : Type u} (cat : ThinCategory W) where
  Obj : W → Type v
  res : ∀ {u v : W}, cat.leq u v → Obj v → Obj u
  res_id : ∀ (w : W) (x : Obj w), res (cat.refl w) x = x
  res_comp :
    ∀ {u v w : W}
      (huv : cat.leq u v)
      (hvw : cat.leq v w)
      (x : Obj w),
        res huv (res hvw x) = res (cat.trans huv hvw) x

structure FourPresheaves {W : Type u} (cat : ThinCategory W) where
  alpha : Presheaf.{u, v} cat
  sigma : Presheaf.{u, v} cat
  pi : Presheaf.{u, v} cat
  rho : Presheaf.{u, v} cat

structure NaturalTransformation {W : Type u} {cat : ThinCategory W}
    (F G : Presheaf.{u, v} cat) where
  app : ∀ w, F.Obj w → G.Obj w
  natural :
    ∀ {u v : W}
      (huv : cat.leq u v)
      (x : F.Obj v),
        G.res huv (app v x) = app u (F.res huv x)

structure FourNaturalTransformations {W : Type u} {cat : ThinCategory W}
    (F G : FourPresheaves.{u, v} cat) where
  alpha : NaturalTransformation F.alpha G.alpha
  sigma : NaturalTransformation F.sigma G.sigma
  pi : NaturalTransformation F.pi G.pi
  rho : NaturalTransformation F.rho G.rho

structure PresheafRelationFamily {W : Type u} {cat : ThinCategory W}
    (F G : Presheaf.{u, v} cat) where
  Rel : ∀ w, F.Obj w → G.Obj w → Prop
  restrict_closed :
    ∀ {u v : W}
      (huv : cat.leq u v)
      {x : F.Obj v}
      {y : G.Obj v},
        Rel v x y → Rel u (F.res huv x) (G.res huv y)

structure TransitionCoproduct (ι : Type u) (Obj : ι → Type v) where
  Tag : Type u
  src : Tag → ι
  dst : Tag → ι
  map : (t : Tag) → Obj (src t) → Obj (dst t)

structure PresheafTransitionCoproduct {W : Type u} {cat : ThinCategory W}
    (F G : Presheaf.{u, v} cat) where
  Tag : Type u
  app : (t : Tag) → ∀ w, F.Obj w → G.Obj w
  natural :
    ∀ (t : Tag)
      {u v : W}
      (huv : cat.leq u v)
      (x : F.Obj v),
        G.res huv (app t v x) = app t u (F.res huv x)

def TransitionInputSum {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj) : Type (max u v) :=
  Sigma fun t : C.Tag => Obj (C.src t)

def TransitionOutputSum {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj) : Type (max u v) :=
  Sigma fun t : C.Tag => Obj (C.dst t)

def PresheafTransitionInputSum {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (w : W) : Type (max u v) :=
  Sigma fun _ : C.Tag => F.Obj w

def PresheafTransitionOutputSum {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (w : W) : Type (max u v) :=
  Sigma fun _ : C.Tag => G.Obj w

theorem presheaf_identity {W : Type u} {cat : ThinCategory W}
    (F : Presheaf cat) (w : W) (x : F.Obj w) :
    F.res (cat.refl w) x = x :=
  F.res_id w x

theorem presheaf_comp {W : Type u} {cat : ThinCategory W}
    (F : Presheaf cat)
    {u v w : W}
    (huv : cat.leq u v)
    (hvw : cat.leq v w)
    (x : F.Obj w) :
    F.res huv (F.res hvw x) = F.res (cat.trans huv hvw) x :=
  F.res_comp huv hvw x

theorem naturality {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf cat}
    (η : NaturalTransformation F G)
    {u v : W}
    (huv : cat.leq u v)
    (x : F.Obj v) :
    G.res huv (η.app v x) = η.app u (F.res huv x) :=
  η.natural huv x

theorem relation_restrict_closed {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf cat}
    (R : PresheafRelationFamily F G)
    {u v : W}
    (huv : cat.leq u v)
    {x : F.Obj v}
    {y : G.Obj v}
    (h : R.Rel v x y) :
    R.Rel u (F.res huv x) (G.res huv y) :=
  R.restrict_closed huv h

theorem presheafTransition_naturality {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf cat}
    (C : PresheafTransitionCoproduct F G)
    (t : C.Tag)
    {u v : W}
    (huv : cat.leq u v)
    (x : F.Obj v) :
    G.res huv (C.app t v x) = C.app t u (F.res huv x) :=
  C.natural t huv x

def presheafTransitionInputInjection {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (t : C.Tag)
    (w : W)
    (x : F.Obj w) : PresheafTransitionInputSum C w :=
  ⟨t, x⟩

def presheafTransitionOutputInjection {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (t : C.Tag)
    (w : W)
    (y : G.Obj w) : PresheafTransitionOutputSum C w :=
  ⟨t, y⟩

def presheafTransitionCoproductMap {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (w : W) :
    PresheafTransitionInputSum C w → PresheafTransitionOutputSum C w :=
  fun z => ⟨z.fst, C.app z.fst w z.snd⟩

theorem presheafTransitionCoproductMap_commutes {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (t : C.Tag)
    (w : W)
    (x : F.Obj w) :
    presheafTransitionCoproductMap C w (presheafTransitionInputInjection C t w x) =
      presheafTransitionOutputInjection C t w (C.app t w x) :=
  rfl

def presheafTransitionOutputCopair {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (w : W)
    {X : Type x}
    (handlers : (t : C.Tag) → G.Obj w → X) :
    PresheafTransitionOutputSum C w → X :=
  fun z => handlers z.fst z.snd

theorem presheafTransitionOutputCopair_beta {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (w : W)
    {X : Type x}
    (handlers : (t : C.Tag) → G.Obj w → X)
    (t : C.Tag)
    (y : G.Obj w) :
    presheafTransitionOutputCopair C w handlers
        (presheafTransitionOutputInjection C t w y) =
      handlers t y :=
  rfl

/--
Fiberwise universality of the output copair for a presheaf transition
coproduct. For each world `w`, the tagged output fiber is a Sigma type, so a
map out of it is uniquely determined by its components on each tag.
-/
theorem presheafTransitionOutputCopair_unique {W : Type u} {cat : ThinCategory W}
    {F G : Presheaf.{u, v} cat}
    (C : PresheafTransitionCoproduct F G)
    (w : W)
    {X : Type x}
    (handlers : (t : C.Tag) → G.Obj w → X)
    (f : PresheafTransitionOutputSum C w → X)
    (h : ∀ (t : C.Tag) (y : G.Obj w),
      f (presheafTransitionOutputInjection C t w y) = handlers t y) :
    f = presheafTransitionOutputCopair C w handlers := by
  funext z
  cases z with
  | mk t y =>
      exact h t y

def transitionInput {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    (t : C.Tag)
    (x : Obj (C.src t)) : Sigma Obj :=
  ⟨C.src t, x⟩

def transitionOutput {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    (t : C.Tag)
    (x : Obj (C.src t)) : Sigma Obj :=
  ⟨C.dst t, C.map t x⟩

theorem transitionOutput_fst {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    (t : C.Tag)
    (x : Obj (C.src t)) :
    (transitionOutput C t x).fst = C.dst t :=
  rfl

def transitionInputInjection {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    (t : C.Tag)
    (x : Obj (C.src t)) : TransitionInputSum C :=
  ⟨t, x⟩

def transitionOutputInjection {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    (t : C.Tag)
    (y : Obj (C.dst t)) : TransitionOutputSum C :=
  ⟨t, y⟩

def transitionCoproductMap {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj) :
    TransitionInputSum C → TransitionOutputSum C :=
  fun z => ⟨z.fst, C.map z.fst z.snd⟩

theorem transitionCoproductMap_commutes {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    (t : C.Tag)
    (x : Obj (C.src t)) :
    transitionCoproductMap C (transitionInputInjection C t x) =
      transitionOutputInjection C t (C.map t x) :=
  rfl

def transitionOutputCopair {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    {X : Type v}
    (handlers : (t : C.Tag) → Obj (C.dst t) → X) :
    TransitionOutputSum C → X :=
  fun z => handlers z.fst z.snd

theorem transitionOutputCopair_beta {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    {X : Type v}
    (handlers : (t : C.Tag) → Obj (C.dst t) → X)
    (t : C.Tag)
    (y : Obj (C.dst t)) :
    transitionOutputCopair C handlers (transitionOutputInjection C t y) =
      handlers t y :=
  rfl

/--
Universality of the output copair in the lightweight Type-level model.
`TransitionOutputSum` is a Sigma type, i.e. the coproduct of the tagged output
fibers in Type. This is deliberately not a mathlib `IsColimit` theorem for an
arbitrary category.
-/
theorem transitionOutputCopair_unique {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    {X : Type v}
    (handlers : (t : C.Tag) → Obj (C.dst t) → X)
    (f : TransitionOutputSum C → X)
    (h : ∀ (t : C.Tag) (y : Obj (C.dst t)),
      f (transitionOutputInjection C t y) = handlers t y) :
    f = transitionOutputCopair C handlers := by
  funext z
  cases z with
  | mk t y =>
      exact h t y

def transitionInputCopair {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    {X : Type v}
    (handlers : (t : C.Tag) → Obj (C.src t) → X) :
    TransitionInputSum C → X :=
  fun z => handlers z.fst z.snd

theorem transitionInputCopair_beta {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    {X : Type v}
    (handlers : (t : C.Tag) → Obj (C.src t) → X)
    (t : C.Tag)
    (x : Obj (C.src t)) :
    transitionInputCopair C handlers (transitionInputInjection C t x) =
      handlers t x :=
  rfl

/--
Universality of the input copair in the lightweight Type-level model.
As above, this states Sigma-type copair uniqueness rather than a general
categorical coproduct theorem.
-/
theorem transitionInputCopair_unique {ι : Type u} {Obj : ι → Type v}
    (C : TransitionCoproduct ι Obj)
    {X : Type v}
    (handlers : (t : C.Tag) → Obj (C.src t) → X)
    (f : TransitionInputSum C → X)
    (h : ∀ (t : C.Tag) (x : Obj (C.src t)),
      f (transitionInputInjection C t x) = handlers t x) :
    f = transitionInputCopair C handlers := by
  funext z
  cases z with
  | mk t x =>
      exact h t x

end Graded

end ERIEC
