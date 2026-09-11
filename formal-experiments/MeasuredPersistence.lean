import ERIEC.Closure

namespace ERIEC.ModelAuditExperiment

/-- The union defining Phi cannot leave a common upper bound on all pi images. -/
theorem phi_subset_of_pi_subset {M C : Type*}
    (piRel : M → Set C) (rhoRel : C → Set M) (K Q : Set C)
    (hpi : ∀ m, piRel m ⊆ Q) : ERIEC.Closure.Phi piRel rhoRel K ⊆ Q := by
  intro c hc
  rcases (by
    simpa [ERIEC.Closure.Phi, ERIEC.Closure.pi_star] using hc :
      ∃ m, m ∈ ERIEC.Closure.rho_star rhoRel K ∧ c ∈ piRel m) with ⟨m, _, hm⟩
  exact hpi m hm

/-- Source-silencing loss pi(m)=Q\Q_m bounds hSelf by future persistence. -/
theorem measured_self_requires_future_persistence {M C : Type*}
    (stopped : M → Set C) (rhoRel : C → Set M) (K Q : Set C)
    (hSelf : K ⊆ ERIEC.Closure.Phi (fun m => Q \ stopped m) rhoRel K) : K ⊆ Q := by
  apply Set.Subset.trans hSelf
  apply phi_subset_of_pi_subset
  intro m c hc
  exact hc.1

theorem no_self_of_past_outside_future {M C : Type*}
    (stopped : M → Set C) (rhoRel : C → Set M) (K Q : Set C)
    (outside : ∃ c, c ∈ K ∧ c ∉ Q) :
    ¬ K ⊆ ERIEC.Closure.Phi (fun m => Q \ stopped m) rhoRel K := by
  intro hSelf
  obtain ⟨c, hc, hn⟩ := outside
  exact hn (measured_self_requires_future_persistence stopped rhoRel K Q hSelf hc)

end ERIEC.ModelAuditExperiment
