import ERIEC.Collapse
import ERIEC.Grading
import Mathlib.Data.Set.Card

namespace ERIEC

namespace Dynamics


/-- Configuration space of intrinsic, sensory, and rank components. -/
structure Conf (C E W : Type*) where
  kappa : Set C
  epsilon : Set E
  rank : W

/-- R2′: drift never decreases rank and strictly increases it while the
intrinsic configuration is nonempty below the top rank. -/
structure R2Prime {C W : Type*} [LinearOrder W] [OrderTop W]
    (drift : W → Set C → W) : Prop where
  nondecreasing : ∀ w K, w ≤ drift w K
  strict_of_nonempty : ∀ w K, K.Nonempty → w ≠ ⊤ → w < drift w K

/-- Every state has at least one internal successor. -/
def InternallyTotal {S : Type*} (stepInt : S → S → Prop) : Prop :=
  ∀ s, ∃ t, stepInt s t

/-- Data-level internal totality, retaining a chosen successor and its proof. -/
structure TotalNext {S : Type*} (stepInt : S → S → Prop) where
  next : S → S
  next_internal : ∀ s, stepInt s (next s)

theorem TotalNext.internallyTotal {S : Type*} {stepInt : S → S → Prop}
    (total : TotalNext stepInt) : InternallyTotal stepInt :=
  fun s => ⟨total.next s, total.next_internal s⟩

/-- Total simultaneous update from §5.1. -/
def upd {C E W : Type*}
    (phi : W → Set C → Set C) (theta : W → Set E → Set E)
    (drift : W → Set C → W) (c : Conf C E W) : Conf C E W :=
  ⟨c.kappa ∩ phi c.rank c.kappa,
   c.epsilon ∩ theta c.rank c.epsilon,
   drift c.rank c.kappa⟩

/-- State-level dynamic frame connected to the total configuration update by
the one-way internal coherence field `h_int`. -/
structure DynFrame (C E W S : Type*) where
  phi : W → Set C → Set C
  theta : W → Set E → Set E
  drift : W → Set C → W
  kappa : S → Set C
  epsilon : S → Set E
  omega : S → W
  stepInt : S → S → Prop
  h_int : ∀ {s t}, stepInt s t →
    Conf.mk (kappa t) (epsilon t) (omega t) =
      upd phi theta drift (Conf.mk (kappa s) (epsilon s) (omega s))

def DynFrame.conf {C E W S : Type*} (frame : DynFrame C E W S)
    (s : S) : Conf C E W :=
  ⟨frame.kappa s, frame.epsilon s, frame.omega s⟩

def DynFrame.update {C E W S : Type*} (frame : DynFrame C E W S) :
    Conf C E W → Conf C E W :=
  upd frame.phi frame.theta frame.drift

/-- A finite internal path indexed by its exact number of edges. -/
inductive InternalPath {S : Type*} (stepInt : S → S → Prop) :
    S → Nat → S → Prop where
  | nil (s : S) : InternalPath stepInt s 0 s
  | cons {s t u : S} {n : Nat} :
      InternalPath stepInt s n t → stepInt t u →
        InternalPath stepInt s (n + 1) u

/-- §5.4(2): configuration along a finite internal path is exactly iteration
of the total update, with the same edge count. -/
theorem path_conf_iterate {C E W S : Type*} (frame : DynFrame C E W S)
    {s t : S} {n : Nat} (path : InternalPath frame.stepInt s n t) :
    frame.conf t = (frame.update^[n]) (frame.conf s) := by
  induction path with
  | nil => rfl
  | cons path hStep ih =>
      calc
        frame.conf _ = frame.update (frame.conf _) := frame.h_int hStep
        _ = frame.update ((frame.update^[_]) (frame.conf _)) := congrArg frame.update ih
        _ = (frame.update^[_ + 1]) (frame.conf _) := by
          rw [Function.iterate_succ_apply']

theorem kappa_descends {C E W : Type*}
    (phi : W → Set C → Set C) (theta : W → Set E → Set E)
    (drift : W → Set C → W) (c : Conf C E W) :
    (upd phi theta drift c).kappa ⊆ c.kappa :=
  Set.inter_subset_left

/-- §5.2: failure of post-fixedness makes the intrinsic update strict. -/
theorem kappa_descends_strict {C E W : Type*}
    (phi : W → Set C → Set C) (theta : W → Set E → Set E)
    (drift : W → Set C → W) (c : Conf C E W)
    (hNotPostfixed : ¬ c.kappa ⊆ phi c.rank c.kappa) :
    (upd phi theta drift c).kappa ⊂ c.kappa := by
  rw [Set.ssubset_def]
  refine ⟨kappa_descends phi theta drift c, ?_⟩
  intro hReverse
  apply hNotPostfixed
  intro x hx
  exact (hReverse hx).2

/-- Once the intrinsic configuration is empty, the hinge is empty and its
nonemptiness certification `h₃` is impossible. -/
theorem hinge_collapse {M E C S : Type*}
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : S → Set C) (epsilon : S → Set E) (s : S)
    (hKappa : kappa s = ∅) :
    Hinge.Act rhoRel sigmaRel kappa epsilon s = ∅ ∧
      ¬ (Hinge.Act rhoRel sigmaRel kappa epsilon s).Nonempty := by
  have hEmpty : Hinge.Act rhoRel sigmaRel kappa epsilon s = ∅ := by
    ext m
    simp [Hinge.Act, Closure.rho_star, hKappa]
  refine ⟨hEmpty, ?_⟩
  rw [hEmpty]
  exact Set.not_nonempty_empty

/-- A finite-collapse certificate includes the permanent empty tail. -/
def FiniteCollapse {C E W : Type*}
    (update : Conf C E W → Conf C E W) (c : Conf C E W) : Prop :=
  ∃ n : Nat, ∀ k : Nat, n ≤ k → ((update^[k]) c).kappa = ∅

/-- The public collapse theorem exposes exactly the certified finite horizon. -/
theorem collapse {C E W : Type*}
    {update : Conf C E W → Conf C E W} {c : Conf C E W}
    (h : FiniteCollapse update c) :
    ∃ n : Nat, ∀ k : Nat, n ≤ k → ((update^[k]) c).kappa = ∅ :=
  h

/-- Remaining strict ranks plus intrinsic cardinality.  This is the variant
used by the bounded termination proof. -/
noncomputable def collapseMeasure {C E W : Type*} [Finite C] [Finite W] [LinearOrder W]
    (c : Conf C E W) : Nat :=
  (Set.Ioi c.rank).ncard + c.kappa.ncard

theorem Ioi_ncard_strict_anti {W : Type*} [Finite W] [LinearOrder W]
    {low high : W} (h : low < high) :
    (Set.Ioi high).ncard < (Set.Ioi low).ncard := by
  apply Set.ncard_lt_ncard (ht := Set.toFinite _)
  rw [Set.ssubset_def]
  refine ⟨?_, ?_⟩
  · intro w hw
    exact h.trans hw
  · intro hReverse
    exact (lt_irrefl high) (hReverse h)

theorem collapseMeasure_update_lt {C E W : Type*}
    [Finite C] [Finite W] [LinearOrder W] [OrderTop W]
    (family : Grading.RankedClosure W C)
    (theta : W → Set E → Set E) (drift : W → Set C → W)
    (r2 : R2Prime drift) (threshold : W)
    (hThreshold : threshold < ⊤) (hSig2 : Grading.sig2 family threshold)
    (c : Conf C E W) (hKappa : c.kappa.Nonempty) :
    collapseMeasure (upd family.op theta drift c) < collapseMeasure c := by
  have hCoreLe : (upd family.op theta drift c).kappa.ncard ≤ c.kappa.ncard :=
    Set.ncard_le_ncard (kappa_descends family.op theta drift c)
  by_cases hTop : c.rank = ⊤
  · have hDrift : drift c.rank c.kappa = c.rank := by
      rw [hTop]
      exact le_antisymm (le_top) (r2.nondecreasing ⊤ c.kappa)
    have hNotPost : ¬ c.kappa ⊆ family.op c.rank c.kappa := by
      rw [hTop]
      exact hSig2 ⊤ hThreshold c.kappa hKappa
    have hCoreStrict :
        (upd family.op theta drift c).kappa.ncard < c.kappa.ncard :=
      Set.ncard_lt_ncard
        (kappa_descends_strict family.op theta drift c hNotPost)
    simp only [collapseMeasure, upd, hDrift]
    exact Nat.add_lt_add_left hCoreStrict _
  · have hRank : c.rank < drift c.rank c.kappa :=
      r2.strict_of_nonempty c.rank c.kappa hKappa hTop
    have hRankStrict := Ioi_ncard_strict_anti hRank
    simp only [collapseMeasure, upd]
    exact Nat.add_lt_add_of_lt_of_le hRankStrict hCoreLe

theorem upd_empty_absorbing {C E W : Type*}
    (phi : W → Set C → Set C) (theta : W → Set E → Set E)
    (drift : W → Set C → W) (c : Conf C E W)
    (hEmpty : c.kappa = ∅) :
    (upd phi theta drift c).kappa = ∅ := by
  simp [upd, hEmpty]

theorem iterate_empty_absorbing {C E W : Type*}
    (phi : W → Set C → Set C) (theta : W → Set E → Set E)
    (drift : W → Set C → W) (c : Conf C E W)
    (hEmpty : c.kappa = ∅) :
    ∀ n, (((upd phi theta drift)^[n]) c).kappa = ∅ := by
  intro n
  induction n generalizing c with
  | zero => exact hEmpty
  | succ n ih =>
      rw [Function.iterate_succ_apply]
      exact ih (upd phi theta drift c) (upd_empty_absorbing phi theta drift c hEmpty)

/-- §5.4(1): finite rank and intrinsic carriers force a permanent empty tail
within `|W|+|C|` updates. -/
theorem collapse_conf {C E W : Type*}
    [Finite C] [Finite W] [LinearOrder W] [OrderTop W]
    (family : Grading.RankedClosure W C)
    (theta : W → Set E → Set E) (drift : W → Set C → W)
    (r2 : R2Prime drift) (threshold : W)
    (hThreshold : threshold < ⊤) (hSig2 : Grading.sig2 family threshold)
    (c0 : Conf C E W) :
    ∃ n ≤ Nat.card W + Nat.card C, ∀ k, n ≤ k →
      (((upd family.op theta drift)^[k]) c0).kappa = ∅ := by
  let update : Conf C E W → Conf C E W := upd family.op theta drift
  have reachesEmpty : ∀ c : Conf C E W,
      ∃ n ≤ collapseMeasure c, ((update^[n]) c).kappa = ∅ := by
    intro c
    let motive : Conf C E W → Prop := fun c =>
      ∃ n ≤ collapseMeasure c, ((update^[n]) c).kappa = ∅
    change motive c
    refine (measure collapseMeasure).wf.induction c ?_
    intro c ih
    by_cases hEmpty : c.kappa = ∅
    · exact ⟨0, Nat.zero_le _, by simp [hEmpty]⟩
    · have hNonempty : c.kappa.Nonempty := Set.nonempty_iff_ne_empty.mpr hEmpty
      have hDecrease : collapseMeasure (update c) < collapseMeasure c :=
        collapseMeasure_update_lt family theta drift r2 threshold
          hThreshold hSig2 c hNonempty
      obtain ⟨n, hn, hAtN⟩ := ih (update c) hDecrease
      refine ⟨n + 1, ?_, ?_⟩
      · exact (Nat.succ_le_succ hn).trans (Nat.succ_le_iff.mpr hDecrease)
      · simpa [update, Function.iterate_succ_apply] using hAtN
  obtain ⟨n, hnMeasure, hAtN⟩ := reachesEmpty c0
  have hMeasureBound : collapseMeasure c0 ≤ Nat.card W + Nat.card C := by
    unfold collapseMeasure
    exact Nat.add_le_add (Set.ncard_le_card (Set.Ioi c0.rank))
      (Set.ncard_le_card c0.kappa)
  refine ⟨n, hnMeasure.trans hMeasureBound, ?_⟩
  intro k hnk
  obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hnk
  rw [Nat.add_comm, Function.iterate_add_apply]
  exact iterate_empty_absorbing family.op theta drift
    (((upd family.op theta drift)^[n]) c0) hAtN d

/-- §5.4(3): chosen internal successors form an infinite internal orbit, and
any configuration-layer collapse certificate transports to a permanent empty
intrinsic tail on that state orbit. -/
theorem total_orbit_collapse {C E W S : Type*}
    (frame : DynFrame C E W S) (total : TotalNext frame.stepInt) (s : S)
    (hCollapse : FiniteCollapse frame.update (frame.conf s)) :
    (∀ n, frame.stepInt ((total.next^[n]) s) ((total.next^[n + 1]) s)) ∧
      ∃ N, ∀ k, N ≤ k → frame.kappa ((total.next^[k]) s) = ∅ := by
  have hEdge : ∀ n,
      frame.stepInt ((total.next^[n]) s) ((total.next^[n + 1]) s) := by
    intro n
    simpa [Function.iterate_succ_apply'] using
      total.next_internal ((total.next^[n]) s)
  have hConf : ∀ n, frame.conf ((total.next^[n]) s) =
      (frame.update^[n]) (frame.conf s) := by
    intro n
    induction n with
    | zero => rfl
    | succ n ih =>
        calc
          frame.conf ((total.next^[n + 1]) s) =
              frame.update (frame.conf ((total.next^[n]) s)) :=
            frame.h_int (hEdge n)
          _ = frame.update ((frame.update^[n]) (frame.conf s)) :=
            congrArg frame.update ih
          _ = (frame.update^[n + 1]) (frame.conf s) := by
            rw [Function.iterate_succ_apply']
  refine ⟨hEdge, ?_⟩
  rcases hCollapse with ⟨N, hTail⟩
  refine ⟨N, fun k hNk => ?_⟩
  have hProjection := congrArg Conf.kappa (hConf k)
  exact hProjection.trans (hTail k hNk)

def Reachable {S : Type*} (step : S → S → Prop) : S → S → Prop :=
  Relation.ReflTransGen step

def downTo {S : Type*} (step : S → S → Prop) (viable : Set S) : Set S :=
  {s | ∃ v, v ∈ viable ∧ Reachable step s v}

/-- Specification name for the reachable down-set `↓V`. -/
abbrev downV {S : Type*} (step : S → S → Prop) (viable : Set S) : Set S :=
  downTo step viable

def K {S : Type*} (step : S → S → Prop) (viable : Set S) : Set S :=
  (downV step viable)ᶜ

/-- Boundary pairs point from the reachable down-set into its complement. -/
def BdPair {S : Type*} (step : S → S → Prop) (viable : Set S) : Set (S × S) :=
  {edge | edge.1 ∈ downV step viable ∧ step edge.1 edge.2 ∧ edge.2 ∈ K step viable}

/-- The complement of the reachable down-set is forward absorbing. -/
theorem K_absorbing {S : Type*} (step : S → S → Prop) (viable : Set S)
    {s t : S} (hs : s ∈ K step viable) (hst : step s t) :
    t ∈ K step viable := by
  intro ht
  apply hs
  rcases ht with ⟨v, hv, htv⟩
  exact ⟨v, hv, Relation.ReflTransGen.head hst htv⟩

/-- §5.3: no transition points from `K` back into `↓V`. -/
theorem BdPair_oneway {S : Type*} (step : S → S → Prop) (viable : Set S)
    {s t : S} (hs : s ∈ K step viable) (hst : step s t) :
    t ∉ downV step viable := by
  simpa [K] using K_absorbing step viable hs hst

/-- §5.4: the absorbing region is not an inverse image of observations. -/
def INS {S Ω : Type*} (observe : S → Ω) (region : Set S) : Prop :=
  ∀ observed : Set Ω, observe ⁻¹' observed ≠ region

/-- §5.7: INS is exactly the existence of an observation fiber mixing the
inside and outside of the absorbing region. -/
theorem INS_iff_fiber {S Ω : Type*} (observe : S → Ω) (region : Set S) :
    INS observe region ↔
      ∃ inside, inside ∈ region ∧
        ∃ outside, outside ∉ region ∧ observe inside = observe outside := by
  classical
  constructor
  · intro hINS
    by_contra hNoMixed
    apply hINS (observe '' region)
    apply Set.Subset.antisymm
    · intro x hx
      rcases hx with ⟨inside, hInside, hObs⟩
      by_contra hOutside
      apply hNoMixed
      exact ⟨inside, hInside, x, hOutside, hObs⟩
    · intro inside hInside
      exact ⟨inside, hInside, rfl⟩
  · rintro ⟨inside, hInside, outside, hOutside, hSame⟩ observed hPreimage
    apply hOutside
    rw [← hPreimage]
    change observe outside ∈ observed
    have hInsidePreimage : inside ∈ observe ⁻¹' observed := by
      rw [hPreimage]
      exact hInside
    change observe inside ∈ observed at hInsidePreimage
    rw [← hSame]
    exact hInsidePreimage

universe u

/-- The rank-indexed core carried by a state. -/
def coreOf {S W : Type*} (core : W → Type u) (omega : S → W) (s : S) : Type u :=
  core (omega s)

/-- An external transition that transports between isomorphic state cores. -/
def Transport {S W : Type*} (stepExt : S → S → Prop)
    (core : W → Type u) (omega : S → W) (s t : S) : Prop :=
  stepExt s t ∧ Nonempty (coreOf core omega s ≃ coreOf core omega t)

end Dynamics

end ERIEC
