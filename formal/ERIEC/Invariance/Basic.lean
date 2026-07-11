import ERIEC.Hinge

namespace ERIEC
namespace Invariance

/-- Direct image notation used by §12. -/
def image {α β : Type*} (e : α ≃ β) (X : Set α) : Set β := e '' X

/-- Static frame carrying exactly the relations and state-indexed data used by
the invariance statements. -/
structure StaticFrame (A E C S W : Type*) where
  alphaRel : A → Set E
  sigmaRel : E → Set A
  piRel : A → Set C
  rhoRel : C → Set A
  kappa : S → Set C
  epsilon : S → Set E
  boundary : Set C
  omega : S → W

/-- State-indexed form of the four DC clauses. -/
def StaticFrame.DCAt {A E C S W : Type*}
    (F : StaticFrame A E C S W) (s : S) : Prop :=
  F.kappa s ⊆ Closure.Phi F.piRel F.rhoRel (F.kappa s) ∧
  F.epsilon s ⊆ Hinge.T_prime F.alphaRel F.sigmaRel (F.epsilon s) ∧
  (Hinge.Act F.rhoRel F.sigmaRel F.kappa F.epsilon s).Nonempty ∧
  (F.kappa s ∩ F.boundary).Nonempty

/-- A strict-square static isomorphism, including the four configuration
compatibilities from Definition 12.1. -/
structure KIso {A E C S A' E' C' S' W : Type*}
    (F : StaticFrame A E C S W) (F' : StaticFrame A' E' C' S' W) where
  hA : A ≃ A'
  hE : E ≃ E'
  hC : C ≃ C'
  hS : S ≃ S'
  alpha_iff : ∀ a e, e ∈ F.alphaRel a ↔ hE e ∈ F'.alphaRel (hA a)
  sigma_iff : ∀ e a, a ∈ F.sigmaRel e ↔ hA a ∈ F'.sigmaRel (hE e)
  pi_iff : ∀ a c, c ∈ F.piRel a ↔ hC c ∈ F'.piRel (hA a)
  rho_iff : ∀ c a, a ∈ F.rhoRel c ↔ hA a ∈ F'.rhoRel (hC c)
  kappa_image : ∀ s, image hC (F.kappa s) = F'.kappa (hS s)
  epsilon_image : ∀ s, image hE (F.epsilon s) = F'.epsilon (hS s)
  boundary_image : image hC F.boundary = F'.boundary
  omega_eq : ∀ s, F'.omega (hS s) = F.omega s

end Invariance
end ERIEC
