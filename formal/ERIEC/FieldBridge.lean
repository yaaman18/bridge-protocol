import ERIEC.Adjunction

namespace ERIEC

namespace FieldBridge

universe u v

/-!
The field bridge is an observation-layer contract.  It does not extend the
individual-level Body or DC structures.  In particular, identifying a clamp
measurement with the theoretical sensory relation is carried explicitly as an
assumption rather than derived from numerical execution.
-/

/-- Explicit semantic assumption that a clamp-measured finite relation denotes
the theoretical sensory relation.  The pointwise biconditional is data: this
structure does not claim that a numerical clamp experiment proves it. -/
structure ClampSigmaIdentificationAssumption (M : Type u) (E : Type v) where
  measuredSigma : E → Set M
  theoreticalSigma : E → Set M
  identifies : ∀ e m, m ∈ measuredSigma e ↔ m ∈ theoreticalSigma e

theorem measuredSigma_eq_theoreticalSigma {M : Type u} {E : Type v}
    (h : ClampSigmaIdentificationAssumption M E) :
    h.measuredSigma = h.theoreticalSigma := by
  funext e
  ext m
  exact h.identifies e m

end FieldBridge

end ERIEC
