import Mathlib.Data.Bool.Basic
import ERIEC.Centering
import ERIEC.Richness

namespace ERIEC

namespace Markers

universe u

structure FMMarkers where
  fm1_global : Bool
  fm2_sensorimotor : Bool
  fm3_selfMonitoring : Bool
  fm4_world : Bool
  deriving DecidableEq

inductive FunctionalClass where
  | consciousMarker
  | blindsightAnalog
  | nonconsciousMarker
  deriving DecidableEq

def classify (markers : FMMarkers) : FunctionalClass :=
  if markers.fm1_global && markers.fm2_sensorimotor &&
      markers.fm3_selfMonitoring && markers.fm4_world then
    .consciousMarker
  else if markers.fm1_global && markers.fm4_world &&
      (!markers.fm2_sensorimotor || !markers.fm3_selfMonitoring) then
    .blindsightAnalog
  else
    .nonconsciousMarker

def Conscious (markers : FMMarkers) : Prop :=
  markers.fm1_global = true ∧ markers.fm2_sensorimotor = true ∧
    markers.fm3_selfMonitoring = true ∧ markers.fm4_world = true

def Blind (markers : FMMarkers) : Prop :=
  markers.fm1_global = true ∧ markers.fm4_world = true ∧
    (markers.fm2_sensorimotor = false ∨ markers.fm3_selfMonitoring = false)

theorem conscious_classification {markers : FMMarkers} (h : Conscious markers) :
    classify markers = .consciousMarker := by
  rcases h with ⟨h1, h2, h3, h4⟩
  simp [classify, h1, h2, h3, h4]

theorem blind_classification {markers : FMMarkers} (h : Blind markers) :
    classify markers = .blindsightAnalog := by
  rcases h with ⟨h1, h4, h2 | h3⟩
  · simp [classify, h1, h2, h4]
  · simp [classify, h1, h3, h4]

/-- v5.1 §9.1: the closure operator obtained by removing action `m` from
the current `ρ⋆` action support before applying `π⋆`. -/
def phiMinus {A E C S W : Type*} (F : Invariance.StaticFrame A E C S W)
    (m : A) (Y : Set C) : Set C :=
  Closure.pi_star F.piRel (Closure.rho_star F.rhoRel Y \ {m})

/-- v5.1 §9.1: FM1 as a static predicate over a `StaticFrame`. -/
def FM1 {A E C S W : Type*} (F : Invariance.StaticFrame A E C S W)
    (m : A) (s : S) : Prop :=
  ¬ F.kappa s ⊆ phiMinus F m (F.kappa s)

/-- v5.1 §9.3: FM2 as multivalent sensorimotor integration. -/
def FM2 {A E C S W : Type*} (F : Invariance.StaticFrame A E C S W)
    (m : A) (_s : S) : Prop :=
  Richness.Branch F.alphaRel m

/-- v5.1 §4/§9: concrete hinge membership for an action at a state. -/
def staticInH {A E C S W : Type*} (F : Invariance.StaticFrame A E C S W)
    (m : A) (s : S) : Prop :=
  m ∈ Hinge.Act F.rhoRel F.sigmaRel F.kappa F.epsilon s

/-- ‡ v5.1 §9.4 / v5.2 §25.2: the extra dyn+lab data needed for
FM3. It is kept separate from `StaticFrame` so that static marker proofs do
not acquire reconstructed dependencies. -/
structure FM3Frame (A E C S W Ωι : Type*) where
  static : Invariance.StaticFrame A E C S W
  stepLabel : A → S → S → Prop
  interoception : S → Ωι

/-- ‡ v5.2 §25.2: dyn+lab compatible isomorphism for FM3 frames. -/
structure FM3Iso {A E C S A' E' C' S' W Ωι Ωι' : Type*}
    (F : FM3Frame A E C S W Ωι)
    (F' : FM3Frame A' E' C' S' W Ωι') where
  static : Invariance.KIso F.static F'.static
  hI : Ωι ≃ Ωι'
  step_iff :
    ∀ m s t, F.stepLabel m s t ↔
      F'.stepLabel (static.hA m) (static.hS s) (static.hS t)
  interoception_preserves :
    ∀ s, hI (F.interoception s) = F'.interoception (static.hS s)

/-- ‡ v5.1 §9.4: FM3 detects an `m`-labelled transition with changed
interoception. -/
def FM3 {A E C S W Ωι : Type*} (F : FM3Frame A E C S W Ωι)
    (m : A) (s : S) : Prop :=
  ∃ t, F.stepLabel m s t ∧ F.interoception t ≠ F.interoception s

/-- v5.2 §25.1 specialized to dyn+lab marker predicates. -/
structure DynLabInvariantFamily where
  Pred : {A E C S W Ωι : Type u} →
    FM3Frame A E C S W Ωι → A → S → Prop
  invariant :
    ∀ {A E C S A' E' C' S' W Ωι Ωι' : Type u}
      {F : FM3Frame A E C S W Ωι}
      {F' : FM3Frame A' E' C' S' W Ωι'}
      (h : FM3Iso F F') (m : A) (s : S),
        @Pred A E C S W Ωι F m s ↔
          @Pred A' E' C' S' W Ωι' F' (h.static.hA m) (h.static.hS s)

/-- v5.1 §9.5 / v5.2 §25.2: representation data needed for FM4.
`spectralProjection` abstracts `P_eta`; `zero` is explicit to avoid importing
analytic vector-space machinery for the invariant skeleton. -/
structure FM4Frame (A E C S W V : Type*) where
  static : Invariance.StaticFrame A E C S W
  representation : A → V
  spectralProjection : V → V
  zero : V

/-- v5.2 §25.2: dyn+rep compatible isomorphism for FM4 frames. -/
structure FM4Iso {A E C S A' E' C' S' W V V' : Type*}
    (F : FM4Frame A E C S W V)
    (F' : FM4Frame A' E' C' S' W V') where
  static : Invariance.KIso F.static F'.static
  hV : V ≃ V'
  zero_preserves : hV F.zero = F'.zero
  representation_preserves :
    ∀ m, hV (F.representation m) = F'.representation (static.hA m)
  projection_preserves :
    ∀ v, hV (F.spectralProjection v) = F'.spectralProjection (hV v)

/-- v5.1 §9.5: FM4 as nonzero projection of the action representation. -/
def FM4 {A E C S W V : Type*} (F : FM4Frame A E C S W V) (m : A) : Prop :=
  F.spectralProjection (F.representation m) ≠ F.zero

/-- v5.2 §25.1 specialized to dyn+rep marker predicates. -/
structure DynRepInvariantFamily where
  Pred : {A E C S W V : Type u} →
    FM4Frame A E C S W V → A → S → Prop
  invariant :
    ∀ {A E C S A' E' C' S' W V V' : Type u}
      {F : FM4Frame A E C S W V}
      {F' : FM4Frame A' E' C' S' W V'}
      (h : FM4Iso F F') (m : A) (s : S),
        @Pred A E C S W V F m s ↔
          @Pred A' E' C' S' W V' F' (h.static.hA m) (h.static.hS s)

/-- v5.1 §9.5 / v5.2 §25.4: combined marker frame for the structural
`Conscious`/`Blind` predicates. `inH` abstracts membership in the current
hinge set; FM3 supplies the inherited ‡ dependency. -/
structure FullMarkerFrame (A E C S W Ωι V : Type*) where
  static : Invariance.StaticFrame A E C S W
  inH : A → S → Prop
  stepLabel : A → S → S → Prop
  interoception : S → Ωι
  representation : A → V
  spectralProjection : V → V
  zero : V

def FullMarkerFrame.toFM3 {A E C S W Ωι V : Type*}
    (F : FullMarkerFrame A E C S W Ωι V) : FM3Frame A E C S W Ωι where
  static := F.static
  stepLabel := F.stepLabel
  interoception := F.interoception

def FullMarkerFrame.toFM4 {A E C S W Ωι V : Type*}
    (F : FullMarkerFrame A E C S W Ωι V) : FM4Frame A E C S W V where
  static := F.static
  representation := F.representation
  spectralProjection := F.spectralProjection
  zero := F.zero

/-- v5.2 §25.2: all compatibility fields needed for `ConsciousAt` and
`BlindAt`. -/
structure FullMarkerIso {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    (F : FullMarkerFrame A E C S W Ωι V)
    (F' : FullMarkerFrame A' E' C' S' W Ωι' V') where
  static : Invariance.KIso F.static F'.static
  inH_iff :
    ∀ m s, F.inH m s ↔ F'.inH (static.hA m) (static.hS s)
  hI : Ωι ≃ Ωι'
  step_iff :
    ∀ m s t, F.stepLabel m s t ↔
      F'.stepLabel (static.hA m) (static.hS s) (static.hS t)
  interoception_preserves :
    ∀ s, hI (F.interoception s) = F'.interoception (static.hS s)
  hV : V ≃ V'
  zero_preserves : hV F.zero = F'.zero
  representation_preserves :
    ∀ m, hV (F.representation m) = F'.representation (static.hA m)
  projection_preserves :
    ∀ v, hV (F.spectralProjection v) = F'.spectralProjection (hV v)

/-- A full marker frame whose abstract `inH` field is the concrete hinge
membership induced by its static frame. -/
def FullMarkerFrame.UsesStaticInH {A E C S W Ωι V : Type*}
    (F : FullMarkerFrame A E C S W Ωι V) : Prop :=
  ∀ m s, F.inH m s ↔ staticInH F.static m s

/-- Compatibility data for all full-marker fields except `inH`. When both
frames use concrete static hinge membership, this data induces a `FullMarkerIso`. -/
structure FullMarkerCoreIso {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    (F : FullMarkerFrame A E C S W Ωι V)
    (F' : FullMarkerFrame A' E' C' S' W Ωι' V') where
  static : Invariance.KIso F.static F'.static
  hI : Ωι ≃ Ωι'
  step_iff :
    ∀ m s t, F.stepLabel m s t ↔
      F'.stepLabel (static.hA m) (static.hS s) (static.hS t)
  interoception_preserves :
    ∀ s, hI (F.interoception s) = F'.interoception (static.hS s)
  hV : V ≃ V'
  zero_preserves : hV F.zero = F'.zero
  representation_preserves :
    ∀ m, hV (F.representation m) = F'.representation (static.hA m)
  projection_preserves :
    ∀ v, hV (F.spectralProjection v) = F'.spectralProjection (hV v)

/-- v5.2 §25.2: a full-marker center symmetry using concrete static hinge
membership for the `inH` component. -/
structure FullMarkerCenterSymmetry {A E C S W Ωι V : Type*}
    (F : FullMarkerFrame A E C S W Ωι V) (m m' : A) where
  iso : FullMarkerCoreIso F F
  maps_center : iso.static.hA m = m'

/-- A full-marker center symmetry that fixes the observed state. -/
structure FullMarkerFixedCenterSymmetry {A E C S W Ωι V : Type*}
    (F : FullMarkerFrame A E C S W Ωι V) (m m' : A) (s : S)
    extends FullMarkerCenterSymmetry F m m' where
  fixes_state : toFullMarkerCenterSymmetry.iso.static.hS s = s

def FullMarkerIso.toFM3Iso {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerIso F F') : FM3Iso F.toFM3 F'.toFM3 where
  static := h.static
  hI := h.hI
  step_iff := h.step_iff
  interoception_preserves := h.interoception_preserves

def FullMarkerIso.toFM4Iso {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerIso F F') : FM4Iso F.toFM4 F'.toFM4 where
  static := h.static
  hV := h.hV
  zero_preserves := h.zero_preserves
  representation_preserves := h.representation_preserves
  projection_preserves := h.projection_preserves

def FullMarkerCoreIso.toFM3Iso {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerCoreIso F F') : FM3Iso F.toFM3 F'.toFM3 where
  static := h.static
  hI := h.hI
  step_iff := h.step_iff
  interoception_preserves := h.interoception_preserves

def FullMarkerCoreIso.toFM4Iso {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerCoreIso F F') : FM4Iso F.toFM4 F'.toFM4 where
  static := h.static
  hV := h.hV
  zero_preserves := h.zero_preserves
  representation_preserves := h.representation_preserves
  projection_preserves := h.projection_preserves

/-- ‡ Structural marker version of v5.1 `Conscious(m,s)`. The old Boolean
`Conscious` API is retained unchanged, so this structural predicate uses an
`At` suffix. -/
def ConsciousAt {A E C S W Ωι V : Type*}
    (F : FullMarkerFrame A E C S W Ωι V) (m : A) (s : S) : Prop :=
  F.inH m s ∧
    FM1 F.static m s ∧
    FM2 F.static m s ∧
    FM3 F.toFM3 m s ∧
    FM4 F.toFM4 m

/-- ‡ Structural marker version of v5.1 `Blind(m,s)`. -/
def BlindAt {A E C S W Ωι V : Type*}
    (F : FullMarkerFrame A E C S W Ωι V) (m : A) (s : S) : Prop :=
  F.inH m s ∧
    FM1 F.static m s ∧
    FM4 F.toFM4 m ∧
    ¬ (FM2 F.static m s ∧ FM3 F.toFM3 m s)

/-- v5.2 §25.1 specialized to dyn+lab+rep marker predicates. -/
structure DynLabRepInvariantFamily where
  Pred : {A E C S W Ωι V : Type u} →
    FullMarkerFrame A E C S W Ωι V → A → S → Prop
  invariant :
    ∀ {A E C S A' E' C' S' W Ωι Ωι' V V' : Type u}
      {F : FullMarkerFrame A E C S W Ωι V}
      {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
      (h : FullMarkerIso F F') (m : A) (s : S),
        @Pred A E C S W Ωι V F m s ↔
          @Pred A' E' C' S' W Ωι' V' F' (h.static.hA m) (h.static.hS s)

def andDynLabRepFamily
    (P Q : DynLabRepInvariantFamily) : DynLabRepInvariantFamily where
  Pred := fun F m s => P.Pred F m s ∧ Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    exact Iff.and (P.invariant h m s) (Q.invariant h m s)

def orDynLabRepFamily
    (P Q : DynLabRepInvariantFamily) : DynLabRepInvariantFamily where
  Pred := fun F m s => P.Pred F m s ∨ Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    exact Iff.or (P.invariant h m s) (Q.invariant h m s)

def notDynLabRepFamily
    (P : DynLabRepInvariantFamily) : DynLabRepInvariantFamily where
  Pred := fun F m s => ¬ P.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    exact Iff.not (P.invariant h m s)

def impDynLabRepFamily
    (P Q : DynLabRepInvariantFamily) : DynLabRepInvariantFamily where
  Pred := fun F m s => P.Pred F m s → Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    exact Iff.imp (P.invariant h m s) (Q.invariant h m s)

def iffDynLabRepFamily
    (P Q : DynLabRepInvariantFamily) : DynLabRepInvariantFamily where
  Pred := fun F m s => P.Pred F m s ↔ Q.Pred F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    exact Iff.iff (P.invariant h m s) (Q.invariant h m s)

def trueDynLabRepFamily : DynLabRepInvariantFamily where
  Pred := fun _ _ _ => True
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    simp

def falseDynLabRepFamily : DynLabRepInvariantFamily where
  Pred := fun _ _ _ => False
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    simp

private theorem image_relStar {A B A' B' : Type*}
    (hA : A ≃ A') (hB : B ≃ B')
    (rel : A → Set B) (rel' : A' → Set B')
    (hrel : ∀ a b, b ∈ rel a ↔ hB b ∈ rel' (hA a)) (X : Set A) :
    Invariance.image hB (⋃ a ∈ X, rel a) =
      ⋃ a' ∈ Invariance.image hA X, rel' a' := by
  ext b'
  simp only [Invariance.mem_image, Set.mem_iUnion]
  constructor
  · rintro ⟨a, ha, hab⟩
    exact ⟨hA a, by simpa [Invariance.mem_image] using ha,
      by simpa using (hrel a (hB.symm b')).mp (by simpa using hab)⟩
  · rintro ⟨a', ha', hab'⟩
    exact ⟨hA.symm a', by simpa [Invariance.mem_image] using ha',
      (hrel (hA.symm a') (hB.symm b')).mpr (by simpa using hab')⟩

theorem image_diff_singleton {A A' : Type*} (hA : A ≃ A') (X : Set A) (m : A) :
    Invariance.image hA (X \ {m}) = Invariance.image hA X \ {hA m} := by
  ext m'
  constructor
  · intro hm'
    have hpre : hA.symm m' ∈ X ∧ hA.symm m' ∉ ({m} : Set A) := by
      simpa [Invariance.mem_image] using hm'
    have hrhs : hA.symm m' ∈ X ∧ m' ∉ ({hA m} : Set A') := by
      exact ⟨hpre.1, by
        intro hm''
        exact hpre.2 (by
          apply hA.injective
          simpa using hm'')⟩
    simpa [Invariance.mem_image] using hrhs
  · intro hm'
    have hpre : hA.symm m' ∈ X ∧ m' ∉ ({hA m} : Set A') := by
      simpa [Invariance.mem_image] using hm'
    have hlhs : hA.symm m' ∈ X ∧ hA.symm m' ∉ ({m} : Set A) := by
      exact ⟨hpre.1, by
        intro hm''
        have heq : hA.symm m' = m := by simpa using hm''
        exact hpre.2 (by
          calc
            m' = hA (hA.symm m') := (hA.apply_symm_apply m').symm
            _ = hA m := congrArg hA heq)⟩
    simpa [Invariance.mem_image] using hlhs

theorem phiMinus_bisim {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') (m : A) (Y : Set C) :
    Invariance.image h.hC (phiMinus F m Y) =
      phiMinus F' (h.hA m) (Invariance.image h.hC Y) := by
  unfold phiMinus Closure.pi_star Closure.rho_star
  rw [image_relStar h.hA h.hC F.piRel F'.piRel h.pi_iff]
  rw [image_diff_singleton h.hA (⋃ c ∈ Y, F.rhoRel c) m]
  rw [image_relStar h.hC h.hA F.rhoRel F'.rhoRel h.rho_iff]

theorem fm1_subset_forward {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') {m : A} {s : S}
    (hsubset : F.kappa s ⊆ phiMinus F m (F.kappa s)) :
    F'.kappa (h.hS s) ⊆ phiMinus F' (h.hA m) (F'.kappa (h.hS s)) := by
  intro c' hc'
  have hcImage : c' ∈ Invariance.image h.hC (F.kappa s) := by
    simpa [h.kappa_image s] using hc'
  have hcPre : h.hC.symm c' ∈ F.kappa s := by
    simpa [Invariance.mem_image] using hcImage
  have hPhiImage :
      c' ∈ Invariance.image h.hC (phiMinus F m (F.kappa s)) := by
    simpa [Invariance.mem_image] using hsubset hcPre
  have hPhi := phiMinus_bisim h m (F.kappa s)
  simpa [h.kappa_image s, hPhi] using hPhiImage

theorem fm1_subset_bisim {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') (m : A) (s : S) :
    (F.kappa s ⊆ phiMinus F m (F.kappa s)) ↔
      F'.kappa (h.hS s) ⊆ phiMinus F' (h.hA m) (F'.kappa (h.hS s)) := by
  constructor
  · exact fm1_subset_forward h
  · intro hsubset
    have hback := fm1_subset_forward h.symm (m := h.hA m) (s := h.hS s) hsubset
    simpa [Invariance.KIso.symm] using hback

theorem fm1_invariant {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') (m : A) (s : S) :
    FM1 F m s ↔ FM1 F' (h.hA m) (h.hS s) := by
  unfold FM1
  exact Iff.not (fm1_subset_bisim h m s)

theorem fm2_invariant {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') (m : A) (s : S) :
    FM2 F m s ↔ FM2 F' (h.hA m) (h.hS s) := by
  constructor
  · rintro ⟨e₁, e₂, he₁, he₂, hne⟩
    exact ⟨h.hE e₁, h.hE e₂, (h.alpha_iff m e₁).mp he₁,
      (h.alpha_iff m e₂).mp he₂, fun heq => hne (h.hE.injective heq)⟩
  · rintro ⟨e₁, e₂, he₁, he₂, hne⟩
    refine ⟨h.hE.symm e₁, h.hE.symm e₂, ?_, ?_, ?_⟩
    · exact (h.alpha_iff m (h.hE.symm e₁)).mpr (by simpa using he₁)
    · exact (h.alpha_iff m (h.hE.symm e₂)).mpr (by simpa using he₂)
    · intro heq
      exact hne (by simpa using congrArg h.hE heq)

/-- v5.2 §25.4(1): concrete hinge membership is invariant under static
compatible isomorphisms. -/
theorem staticInH_invariant {A E C S A' E' C' S' W : Type*}
    {F : Invariance.StaticFrame A E C S W}
    {F' : Invariance.StaticFrame A' E' C' S' W}
    (h : Invariance.KIso F F') (m : A) (s : S) :
    staticInH F m s ↔ staticInH F' (h.hA m) (h.hS s) := by
  have hHinge :=
    (Invariance.static_closure_bisim h).2.2 (F.kappa s) (F.epsilon s)
  have hAct :
      Invariance.image h.hA
          (Hinge.Act F.rhoRel F.sigmaRel F.kappa F.epsilon s) =
        Hinge.Act F'.rhoRel F'.sigmaRel F'.kappa F'.epsilon (h.hS s) := by
    simpa [Hinge.Act, h.kappa_image s, h.epsilon_image s] using hHinge
  constructor
  · intro hm
    have hmImage :
        h.hA m ∈ Invariance.image h.hA
          (Hinge.Act F.rhoRel F.sigmaRel F.kappa F.epsilon s) := by
      simpa [staticInH, Invariance.mem_image] using hm
    simpa [staticInH, hAct] using hmImage
  · intro hm
    have hmImage :
        h.hA m ∈ Invariance.image h.hA
          (Hinge.Act F.rhoRel F.sigmaRel F.kappa F.epsilon s) := by
      simpa [staticInH, hAct] using hm
    simpa [staticInH, Invariance.mem_image] using hmImage

/-- ‡ v5.2 §25.4(4): FM3 is invariant under dyn+lab compatible
isomorphisms. -/
theorem fm3_invariant {A E C S A' E' C' S' W Ωι Ωι' : Type*}
    {F : FM3Frame A E C S W Ωι}
    {F' : FM3Frame A' E' C' S' W Ωι'}
    (h : FM3Iso F F') (m : A) (s : S) :
    FM3 F m s ↔ FM3 F' (h.static.hA m) (h.static.hS s) := by
  constructor
  · rintro ⟨t, hstep, hne⟩
    refine ⟨h.static.hS t, (h.step_iff m s t).mp hstep, ?_⟩
    intro heq
    exact hne (h.hI.injective (by
      calc
        h.hI (F.interoception t) = F'.interoception (h.static.hS t) :=
          h.interoception_preserves t
        _ = F'.interoception (h.static.hS s) := heq
        _ = h.hI (F.interoception s) := (h.interoception_preserves s).symm))
  · rintro ⟨t', hstep, hne⟩
    refine ⟨h.static.hS.symm t', ?_, ?_⟩
    · exact (h.step_iff m s (h.static.hS.symm t')).mpr (by simpa using hstep)
    · intro heq
      exact hne (by
        calc
          F'.interoception t' =
              F'.interoception (h.static.hS (h.static.hS.symm t')) := by simp
          _ = h.hI (F.interoception (h.static.hS.symm t')) :=
              (h.interoception_preserves (h.static.hS.symm t')).symm
          _ = h.hI (F.interoception s) := congrArg h.hI heq
          _ = F'.interoception (h.static.hS s) := h.interoception_preserves s)

/-- v5.2 §25.4(5): FM4 is invariant under dyn+rep compatible
isomorphisms. -/
theorem fm4_invariant {A E C S A' E' C' S' W V V' : Type*}
    {F : FM4Frame A E C S W V}
    {F' : FM4Frame A' E' C' S' W V'}
    (h : FM4Iso F F') (m : A) :
    FM4 F m ↔ FM4 F' (h.static.hA m) := by
  constructor
  · intro hne heq
    exact hne (h.hV.injective (by
      calc
        h.hV (F.spectralProjection (F.representation m)) =
            F'.spectralProjection (h.hV (F.representation m)) :=
          h.projection_preserves (F.representation m)
        _ = F'.spectralProjection (F'.representation (h.static.hA m)) := by
          rw [h.representation_preserves m]
        _ = F'.zero := heq
        _ = h.hV F.zero := h.zero_preserves.symm))
  · intro hne heq
    exact hne (by
      calc
        F'.spectralProjection (F'.representation (h.static.hA m)) =
            F'.spectralProjection (h.hV (F.representation m)) := by
          rw [← h.representation_preserves m]
        _ = h.hV (F.spectralProjection (F.representation m)) :=
          (h.projection_preserves (F.representation m)).symm
        _ = h.hV F.zero := congrArg h.hV heq
        _ = F'.zero := h.zero_preserves)

/-- ‡ v5.2 §25.4(6): structural `ConsciousAt` is invariant under
dyn+lab+rep compatible isomorphisms. -/
theorem consciousAt_invariant
    {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerIso F F') (m : A) (s : S) :
    ConsciousAt F m s ↔ ConsciousAt F' (h.static.hA m) (h.static.hS s) := by
  unfold ConsciousAt
  exact Iff.and (h.inH_iff m s)
    (Iff.and (fm1_invariant h.static m s)
      (Iff.and (fm2_invariant h.static m s)
        (Iff.and (fm3_invariant h.toFM3Iso m s)
          (fm4_invariant h.toFM4Iso m))))

/-- ‡ v5.2 §25.4(6): structural `BlindAt` is invariant under dyn+lab+rep
compatible isomorphisms. -/
theorem blindAt_invariant
    {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerIso F F') (m : A) (s : S) :
    BlindAt F m s ↔ BlindAt F' (h.static.hA m) (h.static.hS s) := by
  unfold BlindAt
  exact Iff.and (h.inH_iff m s)
    (Iff.and (fm1_invariant h.static m s)
      (Iff.and (fm4_invariant h.toFM4Iso m)
        (Iff.not (Iff.and (fm2_invariant h.static m s)
          (fm3_invariant h.toFM3Iso m s)))))

theorem FullMarkerCoreIso.staticInH_iff
    {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerCoreIso F F')
    (hF : F.UsesStaticInH) (hF' : F'.UsesStaticInH) (m : A) (s : S) :
    F.inH m s ↔ F'.inH (h.static.hA m) (h.static.hS s) := by
  calc
    F.inH m s ↔ staticInH F.static m s := hF m s
    _ ↔ staticInH F'.static (h.static.hA m) (h.static.hS s) :=
      staticInH_invariant h.static m s
    _ ↔ F'.inH (h.static.hA m) (h.static.hS s) :=
      (hF' (h.static.hA m) (h.static.hS s)).symm

def FullMarkerCoreIso.toFullMarkerIso
    {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerCoreIso F F')
    (hF : F.UsesStaticInH) (hF' : F'.UsesStaticInH) :
    FullMarkerIso F F' where
  static := h.static
  inH_iff := h.staticInH_iff hF hF'
  hI := h.hI
  step_iff := h.step_iff
  interoception_preserves := h.interoception_preserves
  hV := h.hV
  zero_preserves := h.zero_preserves
  representation_preserves := h.representation_preserves
  projection_preserves := h.projection_preserves

/-- ‡ Concrete-hinge version of `consciousAt_invariant`, where `inH_iff` is
derived from the static hinge definition instead of supplied as a field. -/
theorem consciousAt_invariant_of_staticInH
    {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerCoreIso F F')
    (hF : F.UsesStaticInH) (hF' : F'.UsesStaticInH) (m : A) (s : S) :
    ConsciousAt F m s ↔ ConsciousAt F' (h.static.hA m) (h.static.hS s) :=
  consciousAt_invariant (h.toFullMarkerIso hF hF') m s

/-- ‡ Concrete-hinge version of `blindAt_invariant`, where `inH_iff` is
derived from the static hinge definition instead of supplied as a field. -/
theorem blindAt_invariant_of_staticInH
    {A E C S A' E' C' S' W Ωι Ωι' V V' : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {F' : FullMarkerFrame A' E' C' S' W Ωι' V'}
    (h : FullMarkerCoreIso F F')
    (hF : F.UsesStaticInH) (hF' : F'.UsesStaticInH) (m : A) (s : S) :
    BlindAt F m s ↔ BlindAt F' (h.static.hA m) (h.static.hS s) :=
  blindAt_invariant (h.toFullMarkerIso hF hF') m s

/-- v5.2 §25.3/§25.5: generic fixed-state specialization for any
dyn+lab+rep invariant family over a full marker frame using concrete static
hinge membership. -/
def dynLabRep_fixed_of_staticInH
    (Pred : DynLabRepInvariantFamily)
    {A E C S W Ωι V : Type u}
    {F : FullMarkerFrame A E C S W Ωι V}
    {m m' : A} {s : S}
    (hF : F.UsesStaticInH)
    (φ : FullMarkerFixedCenterSymmetry F m m' s) :
    Pred.Pred F m s ↔ Pred.Pred F m' s := by
  simpa [FullMarkerCoreIso.toFullMarkerIso, φ.maps_center, φ.fixes_state] using
    Pred.invariant (φ.toFullMarkerCenterSymmetry.iso.toFullMarkerIso hF hF) m s

/-- ‡ v5.2 §25.5: fixed center symmetries cannot distinguish structural
`ConsciousAt` when `inH` is the concrete static hinge predicate. -/
theorem consciousAt_horizontal_wall_of_staticInH
    {A E C S W Ωι V : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {m m' : A} {s : S}
    (hF : F.UsesStaticInH)
    (φ : FullMarkerFixedCenterSymmetry F m m' s) :
    ConsciousAt F m s ↔ ConsciousAt F m' s := by
  simpa [φ.maps_center, φ.fixes_state] using
    consciousAt_invariant_of_staticInH φ.toFullMarkerCenterSymmetry.iso hF hF m s

/-- ‡ v5.2 §25.5: fixed center symmetries cannot distinguish structural
`BlindAt` when `inH` is the concrete static hinge predicate. -/
theorem blindAt_horizontal_wall_of_staticInH
    {A E C S W Ωι V : Type*}
    {F : FullMarkerFrame A E C S W Ωι V}
    {m m' : A} {s : S}
    (hF : F.UsesStaticInH)
    (φ : FullMarkerFixedCenterSymmetry F m m' s) :
    BlindAt F m s ↔ BlindAt F m' s := by
  simpa [φ.maps_center, φ.fixes_state] using
    blindAt_invariant_of_staticInH φ.toFullMarkerCenterSymmetry.iso hF hF m s

/-- v5.2 §25.4: FM1 is a static-frame invariant predicate family. -/
def fm1_inv : Centering.InvariantFamily Centering.Strength.statF where
  Pred := fun F m s => FM1 F m s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact fm1_invariant h.static m s

/-- v5.2 §25.4: FM2 is a static-frame invariant predicate family. -/
def fm2_inv : Centering.InvariantFamily Centering.Strength.statF where
  Pred := fun F m s => FM2 F m s
  invariant := by
    intro A E C S A' E' C' S' W F F' h m s
    exact fm2_invariant h.static m s

/-- ‡ v5.2 §25.4: FM3 is a dyn+lab invariant predicate family. -/
def fm3_inv : DynLabInvariantFamily where
  Pred := fun F m s => FM3 F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' F F' h m s
    exact fm3_invariant h m s

/-- v5.2 §25.4: FM4 is a dyn+rep invariant predicate family. -/
def fm4_inv : DynRepInvariantFamily where
  Pred := fun F m _s => FM4 F m
  invariant := by
    intro A E C S A' E' C' S' W V V' F F' h m s
    exact fm4_invariant h m

/-- ‡ v5.2 §25.4: `ConsciousAt` is a dyn+lab+rep invariant family. -/
def consciousAt_inv : DynLabRepInvariantFamily where
  Pred := fun F m s => ConsciousAt F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    exact consciousAt_invariant h m s

/-- ‡ v5.2 §25.4: `BlindAt` is a dyn+lab+rep invariant family. -/
def blindAt_inv : DynLabRepInvariantFamily where
  Pred := fun F m s => BlindAt F m s
  invariant := by
    intro A E C S A' E' C' S' W Ωι Ωι' V V' F F' h m s
    exact blindAt_invariant h m s

end Markers

end ERIEC
