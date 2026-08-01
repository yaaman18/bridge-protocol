import ERIECPCI.Nondegenerate.Manifest

namespace ERIECPCI.Nondegenerate

open ERIEC Dynamics RefModel
open PCI

def mixedFiber :
    MixedFiber
      (StateInScope practice model)
      model.observe candidate.target where
  left := false
  right := true
  left_in_scope := ⟨false, trivial, rfl⟩
  right_in_scope := ⟨true, trivial, rfl⟩
  same_observation := rfl
  target_disagrees := .inl ⟨by
    change false = false
    rfl, by
    change true ≠ false
    decide⟩

def counterexample : RepresentationCounterexample manifest where
  candidate := candidate
  registered := ⟨(), rfl⟩
  admissible := candidate_admissible
  mixedFiber := mixedFiber

theorem no_adequacy_bundle :
    ¬ Nonempty (AdequacyBundle manifest) := by
  rintro ⟨bundle⟩
  exact registeredCounterexample_excludes_bundle bundle counterexample

theorem corresponds_to_nondegINS :
    INS nondegObserve nondegRegion ↔
      Nonempty
        (MixedFiber
          (StateInScope practice model)
          model.observe candidate.target) := by
  constructor
  · intro ins
    rw [INS_iff_fiber] at ins
    rcases ins with ⟨inside, insideRegion, outside, outsideRegion, same⟩
    refine ⟨{
      left := inside
      right := outside
      left_in_scope := ⟨inside, trivial, rfl⟩
      right_in_scope := ⟨outside, trivial, rfl⟩
      same_observation := ?_
      target_disagrees := .inl ⟨?_, ?_⟩
    }⟩
    · exact same
    · exact insideRegion
    · exact outsideRegion
  · rintro ⟨witness⟩
    rw [INS_iff_fiber]
    rcases witness.target_disagrees with disagreement | disagreement
    · exact ⟨witness.left, disagreement.1,
        witness.right, disagreement.2, rfl⟩
    · exact ⟨witness.right, disagreement.2,
        witness.left, disagreement.1, rfl⟩

end ERIECPCI.Nondegenerate
