import ERIEC.Adjunction
import ERIEC.Closure
import ERIEC.Hinge

namespace ERIEC.ModelAuditExperiment

theorem sigma_full_of_one_input_gc {M E : Type*} [Subsingleton E]
    (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (hGC : GaloisConnection (ERIEC.Adj.alpha_star alphaRel) (ERIEC.Adj.sigma_star sigmaRel))
    (epsilon : Set E) (hEpsilon : epsilon.Nonempty) :
    ERIEC.Adj.sigma_star sigmaRel epsilon = Set.univ := by
  obtain ⟨e, he⟩ := hEpsilon
  obtain ⟨functional, converse⟩ := ERIEC.Adj.rigidity_of_gc alphaRel sigmaRel hGC
  ext m
  constructor
  · intro _
    trivial
  · intro _
    obtain ⟨w, hw, _⟩ := functional m
    have heAlpha : e ∈ alphaRel m := (Subsingleton.elim w e) ▸ hw
    have hmSigma : m ∈ sigmaRel e := (converse m e).2 heAlpha
    simpa [ERIEC.Adj.sigma_star] using (show ∃ x, x ∈ epsilon ∧ m ∈ sigmaRel x from ⟨e, he, hmSigma⟩)

/-- Within a one-input adjoint background, nondegenerate hSelf precludes isolated
hSMC/hAct failure. This changes the admissible background, not the definition of DC. -/
theorem one_input_gc_self_implies_smc_and_act {M E C S : Type*} [Subsingleton E]
    (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (piRel : M → Set C) (rhoRel : C → Set M)
    (kappa : S → Set C) (epsilon : S → Set E) (s : S)
    (hGC : GaloisConnection (ERIEC.Adj.alpha_star alphaRel) (ERIEC.Adj.sigma_star sigmaRel))
    (hKappa : (kappa s).Nonempty) (hEpsilon : (epsilon s).Nonempty)
    (hSelf : kappa s ⊆ ERIEC.Closure.Phi piRel rhoRel (kappa s)) :
    (epsilon s ⊆ ERIEC.Hinge.T_prime alphaRel sigmaRel (epsilon s)) ∧
      (ERIEC.Hinge.Act rhoRel sigmaRel kappa epsilon s).Nonempty := by
  obtain ⟨c, hc⟩ := hKappa
  have hPhi := hSelf hc
  obtain ⟨m, hm, _⟩ := (by
    simpa [ERIEC.Closure.Phi, ERIEC.Closure.pi_star] using hPhi :
      ∃ m, m ∈ ERIEC.Closure.rho_star rhoRel (kappa s) ∧ c ∈ piRel m)
  have full := sigma_full_of_one_input_gc alphaRel sigmaRel hGC (epsilon s) hEpsilon
  have hmSigma : m ∈ ERIEC.Adj.sigma_star sigmaRel (epsilon s) := by
    rw [full]
    trivial
  constructor
  · intro e _
    obtain ⟨w, hw, _⟩ := (ERIEC.Adj.rigidity_of_gc alphaRel sigmaRel hGC).1 m
    have heAlpha : e ∈ alphaRel m := (Subsingleton.elim w e) ▸ hw
    simpa [ERIEC.Hinge.T_prime, ERIEC.Adj.alpha_star] using
      (show ∃ motor, motor ∈ ERIEC.Adj.sigma_star sigmaRel (epsilon s) ∧ e ∈ alphaRel motor from
        ⟨m, hmSigma, heAlpha⟩)
  · exact ⟨m, hm, hmSigma⟩

end ERIEC.ModelAuditExperiment
