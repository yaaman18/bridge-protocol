import ERIEC.Gap
import ERIEC.OpenDynamics

namespace ERIEC
namespace KernelOpen

open OpenDynamics

universe u v w

/-- An explicit interface from the states of an open frame to actions of a
static relation kernel. It records non-degeneracy at every exposed state, but
does not identify openness with a target-layer DC predicate. -/
structure Frame {A : Type u} {E : Type v} {Port : Type w}
    (alphaRel : A → Set E) (sigmaRel : E → Set A)
    (O : OpenFrame.{w, max u v} Port) where
  action : O.graph.State → A
  gapUp : ∀ s, Gap.GapUp alphaRel sigmaRel (action s)

theorem action_gapUp {A : Type u} {E : Type v} {Port : Type w}
    {alphaRel : A → Set E} {sigmaRel : E → Set A}
    {O : OpenFrame.{w, max u v} Port}
    (F : Frame alphaRel sigmaRel O) (s : O.graph.State) :
    Gap.GapUp alphaRel sigmaRel (F.action s) :=
  F.gapUp s

end KernelOpen
end ERIEC
