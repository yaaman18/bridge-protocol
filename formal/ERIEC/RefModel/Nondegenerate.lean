import ERIEC.RefModel.Dynamic
import ERIEC.Guard
import ERIEC.Markers

namespace ERIEC
namespace RefModel

open Dynamics

def multiAlpha (_ : Unit) : Set Bool := Set.univ

def nondegUpdate (_ : Conf Unit Bool Bool) : Conf Unit Bool Bool :=
  ⟨∅, ∅, true⟩

def nondegInitial : Conf Unit Bool Bool :=
  ⟨Set.univ, Set.univ, false⟩

theorem nondegFiniteCollapse : FiniteCollapse nondegUpdate nondegInitial := by
  refine ⟨1, ?_⟩
  intro k hk
  cases k with
  | zero => simp at hk
  | succ k => rw [Function.iterate_succ_apply']; rfl

def nondegObserve (_ : Bool) : Unit := ()

def nondegRegion : Set Bool := {false}

theorem nondegINS : INS nondegObserve nondegRegion := by
  rw [INS_iff_fiber]
  exact ⟨false, by simp [nondegRegion], true, by simp [nondegRegion], rfl⟩

def blindMarkers : Markers.FMMarkers :=
  ⟨true, false, true, true⟩

theorem nondegBlind : Markers.Blind blindMarkers := by
  simp [Markers.Blind, blindMarkers]

def identityReachability : Guard.Reachability Bool :=
  ⟨fun source target => source = target⟩

theorem nondegNoTStar : Guard.NoTStar identityReachability := by
  rintro ⟨terminal, hterminal⟩
  cases terminal with
  | false => exact Bool.noConfusion (hterminal true)
  | true => exact Bool.noConfusion (hterminal false)

structure NondegenerateReferenceWitness : Type where
  multivalued : ∃ e₁ e₂ : Bool, e₁ ≠ e₂ ∧
    e₁ ∈ multiAlpha () ∧ e₂ ∈ multiAlpha ()
  collapse : FiniteCollapse nondegUpdate nondegInitial
  ins : INS nondegObserve nondegRegion
  blind : Markers.Blind blindMarkers
  no_terminal : Guard.NoTStar identityReachability

theorem nondegenerate_reference_model : Nonempty NondegenerateReferenceWitness := by
  exact ⟨{
    multivalued := ⟨false, true, by decide, by simp [multiAlpha], by simp [multiAlpha]⟩
    collapse := nondegFiniteCollapse
    ins := nondegINS
    blind := nondegBlind
    no_terminal := nondegNoTStar
  }⟩

end RefModel
end ERIEC
