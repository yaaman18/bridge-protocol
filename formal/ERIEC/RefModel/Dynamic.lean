import ERIEC.RefModel.Stable
import ERIEC.Invariance.External

namespace ERIEC
namespace RefModel

open Dynamics

theorem refDrift_r2prime : R2Prime refDrift := by
  constructor
  · intro w K
    cases w <;> classical simp [refDrift]
  · intro w K hK hTop
    cases w
    · classical simp [refDrift, hK]
    · exact (hTop rfl).elim

def refExternal (_ _ : RefState) : Prop := False

def refCore (s : RefState) : Set Unit := refKappa s

def refCoreIso (K K' : Set Unit) : Prop := K = K'

theorem refE5 : Invariance.E5 refExternal refCore refCoreIso := by
  constructor
  intro s s' t _ hExt
  exact hExt.elim

structure DynamicReferenceWitness : Type where
  stable : StableReferenceWitness
  r2 : R2Prime refDrift
  e5 : Invariance.E5 refExternal refCore refCoreIso

theorem dynamic_reference_model : Nonempty DynamicReferenceWitness := by
  obtain ⟨stable⟩ := stable_reference_model
  exact ⟨⟨stable, refDrift_r2prime, refE5⟩⟩

end RefModel
end ERIEC
