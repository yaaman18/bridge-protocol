import ERIEC.Invariance.Lemmas

namespace ERIEC
namespace Invariance

/-- Strict relation squares commute with direct image. -/
theorem static_rel_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') :
    (∀ a, image h.hE (F.alphaRel a) = F'.alphaRel (h.hA a)) ∧
    (∀ e, image h.hA (F.sigmaRel e) = F'.sigmaRel (h.hE e)) ∧
    (∀ a, image h.hC (F.piRel a) = F'.piRel (h.hA a)) ∧
    (∀ c, image h.hA (F.rhoRel c) = F'.rhoRel (h.hC c)) := by
  constructor
  · intro a; ext e; simp [mem_image, h.alpha_iff]
  constructor
  · intro e; ext a; simp [mem_image, h.sigma_iff]
  constructor
  · intro a; ext c; simp [mem_image, h.pi_iff]
  · intro c; ext a; simp [mem_image, h.rho_iff]

private theorem image_relStar {A B A' B' : Type*}
    (hA : A ≃ A') (hB : B ≃ B')
    (rel : A → Set B) (rel' : A' → Set B')
    (hrel : ∀ a b, b ∈ rel a ↔ hB b ∈ rel' (hA a)) (X : Set A) :
    image hB (⋃ a ∈ X, rel a) = ⋃ a' ∈ image hA X, rel' a' := by
  ext b'
  simp only [mem_image, Set.mem_iUnion]
  constructor
  · rintro ⟨a, ha, hab⟩
    exact ⟨hA a, by simpa [mem_image] using ha,
      by simpa using (hrel a (hB.symm b')).mp (by simpa using hab)⟩
  · rintro ⟨a', ha', hab'⟩
    exact ⟨hA.symm a', by simpa [mem_image] using ha',
      (hrel (hA.symm a') (hB.symm b')).mpr (by simpa using hab')⟩

private theorem phi_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (Y : Set C) :
    image h.hC (Closure.Phi F.piRel F.rhoRel Y) =
      Closure.Phi F'.piRel F'.rhoRel (image h.hC Y) := by
  unfold Closure.Phi Closure.pi_star Closure.rho_star
  rw [image_relStar h.hA h.hC F.piRel F'.piRel h.pi_iff]
  rw [image_relStar h.hC h.hA F.rhoRel F'.rhoRel h.rho_iff]

private theorem nu_forward {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') :
    image h.hC (Closure.nu (Closure.Phi F.piRel F.rhoRel)) ⊆
      Closure.nu (Closure.Phi F'.piRel F'.rhoRel) := by
  apply Closure.coinduction
  rw [← phi_bisim h]
  exact Set.image_mono (Closure.nu_postfixed (Closure.phi_mono F.piRel F.rhoRel))

private theorem nu_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') :
    image h.hC (Closure.nu (Closure.Phi F.piRel F.rhoRel)) =
      Closure.nu (Closure.Phi F'.piRel F'.rhoRel) := by
  apply Set.Subset.antisymm (nu_forward h)
  intro c' hc'
  apply (mem_image h.hC _ c').mpr
  apply nu_forward h.symm
  apply (mem_image h.hC.symm _ (h.hC.symm c')).mpr
  simpa using hc'

private theorem hinge_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (K : Set C) (X : Set E) :
    image h.hA
        (Closure.rho_star F.rhoRel K ∩ Adj.sigma_star F.sigmaRel X) =
      Closure.rho_star F'.rhoRel (image h.hC K) ∩
        Adj.sigma_star F'.sigmaRel (image h.hE X) := by
  have hRho := image_relStar h.hC h.hA F.rhoRel F'.rhoRel h.rho_iff K
  have hSigma := image_relStar h.hE h.hA F.sigmaRel F'.sigmaRel h.sigma_iff X
  simpa [Closure.rho_star, Adj.sigma_star, Closure.pi_star, image_inter] using
    congrArg₂ (· ∩ ·) hRho hSigma

/-- Static isomorphisms preserve `Φ`, its greatest fixed point `νΦ`, and the
hinge intersection. -/
theorem static_closure_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') :
    (∀ Y, image h.hC (Closure.Phi F.piRel F.rhoRel Y) =
      Closure.Phi F'.piRel F'.rhoRel (image h.hC Y)) ∧
    image h.hC (Closure.nu (Closure.Phi F.piRel F.rhoRel)) =
      Closure.nu (Closure.Phi F'.piRel F'.rhoRel) ∧
    (∀ K X, image h.hA
      (Closure.rho_star F.rhoRel K ∩ Adj.sigma_star F.sigmaRel X) =
      Closure.rho_star F'.rhoRel (image h.hC K) ∩
        Adj.sigma_star F'.sigmaRel (image h.hE X)) := by
  exact ⟨phi_bisim h, nu_bisim h, hinge_bisim h⟩

private theorem static_tprime_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (X : Set E) :
    image h.hE (Hinge.T_prime F.alphaRel F.sigmaRel X) =
      Hinge.T_prime F'.alphaRel F'.sigmaRel (image h.hE X) := by
  unfold Hinge.T_prime Adj.alpha_star Adj.sigma_star
  rw [image_relStar h.hA h.hE F.alphaRel F'.alphaRel h.alpha_iff]
  rw [image_relStar h.hE h.hA F.sigmaRel F'.sigmaRel h.sigma_iff]

private theorem static_act_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (s : S) :
    image h.hA (Hinge.Act F.rhoRel F.sigmaRel F.kappa F.epsilon s) =
      Hinge.Act F'.rhoRel F'.sigmaRel F'.kappa F'.epsilon (h.hS s) := by
  unfold Hinge.Act
  rw [image_inter]
  have hRho : image h.hA (Closure.rho_star F.rhoRel (F.kappa s)) =
      Closure.rho_star F'.rhoRel (image h.hC (F.kappa s)) := by
    simpa [Closure.rho_star] using
      image_relStar h.hC h.hA F.rhoRel F'.rhoRel h.rho_iff (F.kappa s)
  have hSigma : image h.hA (Adj.sigma_star F.sigmaRel (F.epsilon s)) =
      Adj.sigma_star F'.sigmaRel (image h.hE (F.epsilon s)) := by
    simpa [Adj.sigma_star] using
      image_relStar h.hE h.hA F.sigmaRel F'.sigmaRel h.sigma_iff (F.epsilon s)
  rw [hRho, hSigma, h.kappa_image, h.epsilon_image]

private theorem static_DC_forward {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (s : S) (hs : F.DCAt s) : F'.DCAt (h.hS s) := by
  rcases hs with ⟨hkappa, hepsilon, hact, hboundary⟩
  refine ⟨?_, ?_, ?_, ?_⟩
  · rw [← h.kappa_image, ← phi_bisim h]
    exact Set.image_mono hkappa
  · rw [← h.epsilon_image, ← static_tprime_bisim h]
    exact Set.image_mono hepsilon
  · rw [← static_act_bisim h s]
    exact Set.image_nonempty.mpr hact
  · rw [← h.kappa_image, ← h.boundary_image, ← image_inter]
    exact Set.image_nonempty.mpr hboundary

/-- Static isomorphisms preserve all four DC clauses in both directions. -/
theorem static_DC_bisim {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (s : S) : F.DCAt s ↔ F'.DCAt (h.hS s) := by
  constructor
  · exact static_DC_forward h s
  · intro hs
    have := static_DC_forward h.symm (h.hS s) hs
    simpa [KIso.symm] using this

/-- The intrinsic intersection update commutes with a static isomorphism. -/
theorem internal_bisim_kappa {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (_w : W) (K : Set C) :
    image h.hC (K ∩ Closure.Phi F.piRel F.rhoRel K) =
      image h.hC K ∩ Closure.Phi F'.piRel F'.rhoRel (image h.hC K) := by
  rw [image_inter, phi_bisim h K]

/-- The sensory intersection update commutes with a static isomorphism. -/
theorem internal_bisim_epsilon {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') (X : Set E) :
    image h.hE (X ∩ Hinge.T_prime F.alphaRel F.sigmaRel X) =
      image h.hE X ∩ Hinge.T_prime F'.alphaRel F'.sigmaRel (image h.hE X) := by
  rw [image_inter, static_tprime_bisim h X]
end Invariance
end ERIEC
