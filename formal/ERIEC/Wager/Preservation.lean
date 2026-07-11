import ERIEC.Wager.Richness

namespace ERIEC
namespace Wager

/-- A sentence not containing the fresh predicate `Ph` is unchanged when
`Ph` is definitionally identified with a structural predicate. -/
theorem definitional_extension_conservative {S : Type*}
    (structural : S → Prop) (sentence : Prop) :
    (∃ Ph : S → Prop, (∀ s, Ph s ↔ structural s) ∧ sentence) ↔ sentence := by
  constructor
  · rintro ⟨_, _, hsentence⟩
    exact hsentence
  · intro hsentence
    exact ⟨structural, fun _ => Iff.rfl, hsentence⟩

/-- The particular frozen W1 identification can be introduced and eliminated
without changing any external sentence. -/
theorem W1_identification_conservative {A E C S : Type*}
    (impl : FrozenImpl A E C S) (sentence : Prop) :
    (∃ Ph : S → Prop, W1 impl Ph ∧ sentence) ↔ sentence := by
  constructor
  · rintro ⟨_, _, hsentence⟩
    exact hsentence
  · intro hsentence
    refine ⟨fun s => impl.dc s ∧ impl.nontrivial, ?_, hsentence⟩
    intro s
    rfl

/-- A future axiom pack preserves an independence witness pair exactly when
both concrete witnesses still model that pack. -/
theorem witness_pair_forward_stable {Model : Type*} {W A : Model → Prop}
    {positive negative : Model}
    (hpositive : W positive) (hnegative : ¬ W negative)
    (hApositive : A positive) (hAnegative : A negative) :
    (W positive ∧ A positive) ∧ (¬ W negative ∧ A negative) :=
  ⟨⟨hpositive, hApositive⟩, hnegative, hAnegative⟩

/-- Concrete positive/negative models retained by the frozen protocol. -/
structure WitnessPair (Model : Type*) (sentence : Model → Prop) where
  positive : Model
  negative : Model
  positive_models : sentence positive
  negative_refutes : ¬ sentence negative

def PackPreserves {Model : Type*} {sentence : Model → Prop}
    (pair : WitnessPair Model sentence) (pack : Model → Prop) : Prop :=
  pack pair.positive ∧ pack pair.negative

def ModelsAll {Model : Type*} (packs : List (Model → Prop)) (model : Model) : Prop :=
  ∀ pack ∈ packs, pack model

/-- M-6 finite-release invariant: if every added pack retains both frozen
witnesses, all releases retain the original truth/refutation split. -/
theorem global_frozen_protocol_invariant {Model : Type*} {sentence : Model → Prop}
    (pair : WitnessPair Model sentence) (packs : List (Model → Prop))
    (hpreserves : ∀ pack ∈ packs, PackPreserves pair pack) :
    sentence pair.positive ∧ ¬ sentence pair.negative ∧
      ModelsAll packs pair.positive ∧ ModelsAll packs pair.negative := by
  refine ⟨pair.positive_models, pair.negative_refutes, ?_, ?_⟩
  · intro pack hpack
    exact (hpreserves pack hpack).1
  · intro pack hpack
    exact (hpreserves pack hpack).2

end Wager
end ERIEC
