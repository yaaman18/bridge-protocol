import ERIEC.RefModel.Nondegenerate
import ERIEC.Wager.Richness

namespace ERIEC
namespace RefModel

open Dynamics

def finFullRel {k : ℕ} (_ : Fin k) : Set Unit := Set.univ

def unitFinFullRel {k : ℕ} (_ : Unit) : Set (Fin k) := Set.univ

/-- A concrete target-layer DC whose hinge contains exactly `k` actions. -/
def parameterizedRichDC (k : ℕ) (hk : 0 < k) : DC (Fin k) Unit Unit RefState where
  alphaRel := finFullRel
  sigmaRel := unitFinFullRel
  piRel := finFullRel
  rhoRel := unitFinFullRel
  kappa := refKappa
  epsilon := refEpsilon
  boundary := Set.univ
  s := .s0
  hSelf := by
    intro c _
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star, finFullRel,
      unitFinFullRel, refKappa]
  hSMC := by
    intro e _
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, finFullRel,
      unitFinFullRel, refEpsilon, refKappa]
  hAct := by
    let a : Fin k := ⟨0, hk⟩
    exact ⟨a, by simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, unitFinFullRel,
      refKappa, refEpsilon]⟩
  hBound := by simp [refKappa]

theorem parameterizedRichDC_act_eq_univ (k : ℕ) (hk : 0 < k) :
    Hinge.Act (parameterizedRichDC k hk).rhoRel
      (parameterizedRichDC k hk).sigmaRel
      (parameterizedRichDC k hk).kappa
      (parameterizedRichDC k hk).epsilon .s0 = Set.univ := by
  ext a
  simp [parameterizedRichDC, Hinge.Act, Closure.rho_star, Adj.sigma_star,
    unitFinFullRel, refKappa, refEpsilon]

theorem richImpl_hinge_card (k : ℕ) :
    ((Wager.richImpl k).hinge ()).card = k := by
  simp [Wager.richImpl]

theorem richImpl_realized_by_DC (k : ℕ) (hk : 0 < k) :
    (↑((Wager.richImpl k).hinge ()) : Set (Fin k)) =
      Hinge.Act (parameterizedRichDC k hk).rhoRel
        (parameterizedRichDC k hk).sigmaRel
        (parameterizedRichDC k hk).kappa
        (parameterizedRichDC k hk).epsilon .s0 := by
  rw [parameterizedRichDC_act_eq_univ]
  simp [Wager.richImpl]

structure ParameterizedRichReferenceWitness (k : ℕ) : Type where
  dc : DC (Fin k) Unit Unit RefState
  frame : DynFrame Unit Unit Bool RefState
  total : TotalNext frame.stepInt
  r2 : R2Prime refDrift
  e5 : Invariance.E5 refExternal refCore refCoreIso
  hinge_card : ((Wager.richImpl k).hinge ()).card = k
  hinge_realized : (↑((Wager.richImpl k).hinge ()) : Set (Fin k)) =
    Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s

/-- The W-8 family is registered as an actual finite DC/dynamics reference
model for every nonzero threshold. -/
theorem parameterized_rich_reference_model (k : ℕ) (hk : 0 < k) :
    Nonempty (ParameterizedRichReferenceWitness k) := by
  refine ⟨{
    dc := parameterizedRichDC k hk
    frame := stableDynFrame
    total := stableTotalNext
    r2 := refDrift_r2prime
    e5 := refE5
    hinge_card := richImpl_hinge_card k
    hinge_realized := richImpl_realized_by_DC k hk
  }⟩

end RefModel
end ERIEC
