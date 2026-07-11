import ERIEC.Invariance.Basic

namespace ERIEC
namespace Invariance

@[simp] theorem mem_image {α β : Type*} (e : α ≃ β) (X : Set α) (y : β) :
    y ∈ image e X ↔ e.symm y ∈ X := by
  constructor
  · rintro ⟨x, hx, rfl⟩
    simpa using hx
  · intro hy
    exact ⟨e.symm y, hy, e.apply_symm_apply y⟩

theorem image_inter {α β : Type*} (e : α ≃ β) (X Y : Set α) :
    image e (X ∩ Y) = image e X ∩ image e Y := by
  ext y
  simp [mem_image]

theorem image_compl {α β : Type*} (e : α ≃ β) (X : Set α) :
    image e Xᶜ = (image e X)ᶜ := by
  ext y
  simp [mem_image]

namespace KIso

def symm {A E C S A' E' C' S' W : Type*}
    {F : StaticFrame A E C S W} {F' : StaticFrame A' E' C' S' W}
    (h : KIso F F') : KIso F' F where
  hA := h.hA.symm
  hE := h.hE.symm
  hC := h.hC.symm
  hS := h.hS.symm
  alpha_iff a e := by simpa using (h.alpha_iff (h.hA.symm a) (h.hE.symm e)).symm
  sigma_iff e a := by simpa using (h.sigma_iff (h.hE.symm e) (h.hA.symm a)).symm
  pi_iff a c := by simpa using (h.pi_iff (h.hA.symm a) (h.hC.symm c)).symm
  rho_iff c a := by simpa using (h.rho_iff (h.hC.symm c) (h.hA.symm a)).symm
  kappa_image s := by
    ext c
    simpa [mem_image] using (congrArg (fun X => h.hC c ∈ X)
      (h.kappa_image (h.hS.symm s))).symm
  epsilon_image s := by
    ext e
    simpa [mem_image] using (congrArg (fun X => h.hE e ∈ X)
      (h.epsilon_image (h.hS.symm s))).symm
  boundary_image := by
    ext c
    simpa [mem_image] using
      (congrArg (fun X => h.hC c ∈ X) h.boundary_image).symm
  omega_eq s := by simpa using (h.omega_eq (h.hS.symm s)).symm

end KIso
end Invariance
end ERIEC
