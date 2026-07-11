import ERIEC.Invariance.Static
import ERIEC.Dynamics

namespace ERIEC
namespace Invariance

open Dynamics
/-- Drift equivariance is explicit field data, not an inferred theorem. -/
structure DriftEquivariant {C C' W : Type*} (hC : C ≃ C')
    (drift : W → Set C → W) (drift' : W → Set C' → W) : Prop where
  eq : ∀ w K, drift' w (image hC K) = drift w K

def mapConf {C E C' E' W : Type*} (hC : C ≃ C') (hE : E ≃ E')
    (c : Conf C E W) : Conf C' E' W :=
  ⟨image hC c.kappa, image hE c.epsilon, c.rank⟩

/-- Static compatibility plus drift equivariance gives commutation of the full
three-component update. -/
theorem upd_bisim {C E C' E' W : Type*}
    (hC : C ≃ C') (hE : E ≃ E')
    (phi : W → Set C → Set C) (phi' : W → Set C' → Set C')
    (theta : W → Set E → Set E) (theta' : W → Set E' → Set E')
    (drift : W → Set C → W) (drift' : W → Set C' → W)
    (hPhi : ∀ w K, image hC (phi w K) = phi' w (image hC K))
    (hTheta : ∀ w X, image hE (theta w X) = theta' w (image hE X))
    (hDrift : DriftEquivariant hC drift drift') (c : Conf C E W) :
    mapConf hC hE (upd phi theta drift c) =
      upd phi' theta' drift' (mapConf hC hE c) := by
  cases c
  simp [mapConf, upd, image_inter, hPhi, hTheta, hDrift.eq]

/-- A one-step commuting square commutes with every finite iterate. -/
theorem iterate_bisim {A B : Type*}
    (map : A → B) (update : A → A) (update' : B → B)
    (hcomm : ∀ a, map (update a) = update' (map a)) :
    ∀ (n : Nat) (a : A), map ((update^[n]) a) = (update'^[n]) (map a) := by
  intro n
  induction n with
  | zero => intro a; rfl
  | succ n ih =>
      intro a
      simp only [Function.iterate_succ_apply]
      calc
        map ((update^[n]) (update a)) = (update'^[n]) (map (update a)) := ih (update a)
        _ = (update'^[n]) (update' (map a)) := congrArg (update'^[n]) (hcomm a)

/-- Dynamic and observational compatibility required by Theorem 12.5. -/
structure DynamicIso {A E C S A' E' C' S' W Ω : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (static : KIso F F') (step : S → S → Prop) (step' : S' → S' → Prop)
    (observe : S → Ω) (observe' : S' → Ω) : Prop where
  step_iff : ∀ s t, step s t ↔ step' (static.hS s) (static.hS t)
  observe_eq : ∀ s, observe' (static.hS s) = observe s

private theorem reachable_forward {S S' : Type*}
    (hS : S ≃ S') {step : S → S → Prop} {step' : S' → S' → Prop}
    (hstep : ∀ s t, step s t ↔ step' (hS s) (hS t))
    {s t : S} (hst : Reachable step s t) :
    Reachable step' (hS s) (hS t) := by
  induction hst using Relation.ReflTransGen.trans_induction_on with
  | refl => exact Relation.ReflTransGen.refl
  | single h => exact Relation.ReflTransGen.single ((hstep _ _).mp h)
  | trans _ _ ih₁ ih₂ => exact ih₁.trans ih₂

private theorem downV_image {S S' : Type*}
    (hS : S ≃ S') {step : S → S → Prop} {step' : S' → S' → Prop}
    (hstep : ∀ s t, step s t ↔ step' (hS s) (hS t))
    (V : Set S) :
    image hS (downV step V) = downV step' (image hS V) := by
  ext s'
  simp only [mem_image, downV, downTo, Set.mem_setOf_eq]
  constructor
  · rintro ⟨v, hv, hsv⟩
    exact ⟨hS v, by simpa [mem_image] using hv,
      by simpa using reachable_forward hS hstep hsv⟩
  · rintro ⟨v', hv', hsv'⟩
    refine ⟨hS.symm v', ?_, ?_⟩
    · simpa [mem_image] using hv'
    · have hback : ∀ x y, step' x y ↔ step (hS.symm x) (hS.symm y) := by
        intro x y
        simpa using (hstep (hS.symm x) (hS.symm y)).symm
      simpa using reachable_forward hS.symm hback hsv'

private theorem INS_image_iff {S S' Ω : Type*}
    (hS : S ≃ S') (observe : S → Ω) (observe' : S' → Ω)
    (hobserve : ∀ s, observe' (hS s) = observe s) (R : Set S) :
    INS observe R ↔ INS observe' (image hS R) := by
  rw [INS_iff_fiber, INS_iff_fiber]
  constructor
  · rintro ⟨inside, hi, outside, ho, heq⟩
    refine ⟨hS inside, by simpa [mem_image] using hi,
      hS outside, ?_, ?_⟩
    · simpa [mem_image] using ho
    · simpa [hobserve] using heq
  · rintro ⟨inside, hi, outside, ho, heq⟩
    refine ⟨hS.symm inside, by simpa [mem_image] using hi,
      hS.symm outside, ?_, ?_⟩
    · simpa [mem_image] using ho
    · calc
        observe (hS.symm inside) = observe' inside := by
          simpa using (hobserve (hS.symm inside)).symm
        _ = observe' outside := heq
        _ = observe (hS.symm outside) := by
          simpa using hobserve (hS.symm outside)

/-- Observation-compatible dynamic isomorphisms preserve the absorbing region
and therefore preserve INS in both directions. -/
theorem INS_invariant {A E C S A' E' C' S' W Ω : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    {step : S → S → Prop} {step' : S' → S' → Prop}
    {observe : S → Ω} {observe' : S' → Ω}
    (h : KIso F F')
    (hdyn : DynamicIso h step step' observe observe') :
    INS observe (K step {s | F.DCAt s}) ↔
      INS observe' (K step' {s | F'.DCAt s}) := by
  have hV : image h.hS {s | F.DCAt s} = {s | F'.DCAt s} := by
    ext s'
    simp only [mem_image, Set.mem_setOf_eq]
    simpa using static_DC_bisim h (h.hS.symm s')
  have hDown := downV_image h.hS hdyn.step_iff {s | F.DCAt s}
  have hK : image h.hS (K step {s | F.DCAt s}) =
      K step' {s | F'.DCAt s} := by
    unfold K
    rw [image_compl, hDown, hV]
  rw [← hK]
  exact INS_image_iff h.hS observe observe' hdyn.observe_eq _
end Invariance
end ERIEC
