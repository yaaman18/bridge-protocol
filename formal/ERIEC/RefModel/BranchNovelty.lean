import ERIEC.BranchNovelty
import ERIEC.WorldDC
import ERIEC.RefModel.LineageWitness
import ERIEC.RefModel.CollapseTrace
import ERIEC.RefModel.LargeCore

namespace ERIEC
namespace RefModel

/-- Converse consistency for the one-point countermodel DC. -/
theorem unitDC_hConv :
    ∀ m e,
      e ∈ WorldDC.Countermodel.unitDC.alphaRel m ↔
        m ∈ WorldDC.Countermodel.unitDC.sigmaRel e := by
  intro m e
  cases m
  cases e
  simp [WorldDC.Countermodel.unitDC]

/-- Converse consistency for the branch-free growing reference family. -/
theorem richLineageDC_hConv (n : Nat) :
    ∀ m e,
      e ∈ (richLineageDC n).alphaRel m ↔
        m ∈ (richLineageDC n).sigmaRel e := by
  intro m e
  simp [richLineageDC, finFullRel, unitFinFullRel]

/-- Converse consistency for the branch-bearing legacy reference family. -/
theorem branchedRichLineageDC_hConv (n : Nat) :
    ∀ m e,
      e ∈ (branchedRichLineageDC n).alphaRel m ↔
        m ∈ (branchedRichLineageDC n).sigmaRel e := by
  intro m e
  simp [branchedRichLineageDC]

/-- Converse consistency for the stable one-point reference DC. -/
theorem stableDC_hConv :
    ∀ m e, e ∈ stableDC.alphaRel m ↔ m ∈ stableDC.sigmaRel e := by
  intro m e
  simp [stableDC, pointRel]

/-- Converse consistency for the parameterized finite rich DC. -/
theorem parameterizedRichDC_hConv (k : Nat) (hk : 0 < k) :
    ∀ m e,
      e ∈ (parameterizedRichDC k hk).alphaRel m ↔
        m ∈ (parameterizedRichDC k hk).sigmaRel e := by
  intro m e
  simp [parameterizedRichDC, finFullRel, unitFinFullRel]

/-- Converse consistency for the arbitrary-size finite DC. -/
theorem largeFiniteDC_hConv (k : Nat) (hk : 0 < k) :
    ∀ m e,
      e ∈ (largeFiniteDC k hk).alphaRel m ↔
        m ∈ (largeFiniteDC k hk).sigmaRel e := by
  intro m e
  simp [largeFiniteDC, finFullRelation]

/-- Converse consistency for the arbitrary-size AX-core DC. -/
theorem largeAXCoreDC_hConv (k : Nat) (hk : 0 < k) :
    ∀ m e,
      e ∈ (largeAXCoreDC k hk).alphaRel m ↔
        m ∈ (largeAXCoreDC k hk).sigmaRel e := by
  intro m e
  simp [largeAXCoreDC, finFullRelation]

/-- Converse consistency for the pre-collapse reference certificate. -/
theorem collapseInitialDC_hConv :
    ∀ m e,
      e ∈ collapseInitialDC.alphaRel m ↔
        m ∈ collapseInitialDC.sigmaRel e := by
  simpa [collapseInitialDC] using richLineageDC_hConv 0

end RefModel
end ERIEC
