namespace ERIEC

namespace Traceability

universe u v

/-- §26.1: a numbered reference to a definition, theorem, obligation, or meta rule. -/
structure TagRef where
  document : String
  sectionRef : String
  label : String
deriving DecidableEq, Repr

/-- §26.1: every public-facing statement is anchored or explicitly marked. -/
inductive Anchor where
  | tag : TagRef → Anchor
  | cnj : Anchor
  | metaphor : Anchor
deriving DecidableEq, Repr

/-- §26.1: the audit unit for natural-language claims. -/
structure Stmt where
  text : String
  anchor : Anchor
deriving DecidableEq, Repr

def IsTagged : Anchor → Prop
  | .tag _ => True
  | _ => False

def IsExplicitlyMarked : Anchor → Prop
  | .cnj => True
  | .metaphor => True
  | _ => False

theorem anchor_total (a : Anchor) : IsTagged a ∨ IsExplicitlyMarked a := by
  cases a <;> simp [IsTagged, IsExplicitlyMarked]

theorem stmt_has_anchor (s : Stmt) : IsTagged s.anchor ∨ IsExplicitlyMarked s.anchor :=
  anchor_total s.anchor

abbrev Document := List Stmt

def DocumentAnchored (doc : Document) : Prop :=
  ∀ stmt, stmt ∈ doc → IsTagged stmt.anchor ∨ IsExplicitlyMarked stmt.anchor

theorem document_anchored (doc : Document) : DocumentAnchored doc := by
  intro stmt _hmem
  exact stmt_has_anchor stmt

/-- §26.3: an approved strong/neutral synonym pair for a vocabulary item. -/
structure SynonymPair where
  vocabulary : String
  strong : String
  neutral : String
deriving DecidableEq, Repr

/-- §26.3: data needed to run the two-construction vocabulary test. -/
structure VocabularyTest (Text : Type u) (FormulaNF : Type v) where
  pair : SynonymPair
  strongSubst : Text → Text
  neutralSubst : Text → Text
  translate : Text → FormulaNF

/-- A word is proof-anchored when strong and neutral substitutions translate
to the same syntactic normal form. -/
def ProofAnchored {Text : Type u} {FormulaNF : Type v}
    (T : VocabularyTest Text FormulaNF) (text : Text) : Prop :=
  T.translate (T.strongSubst text) = T.translate (T.neutralSubst text)

/-- If the two normal forms differ, the vocabulary item is doing extra work
beyond the current translation image. -/
def ExceedsTranslation {Text : Type u} {FormulaNF : Type v}
    (T : VocabularyTest Text FormulaNF) (text : Text) : Prop :=
  T.translate (T.strongSubst text) ≠ T.translate (T.neutralSubst text)

inductive VocabularyStatus where
  | proofAnchored
  | exceedsTranslation
deriving DecidableEq, Repr

def vocabularyStatus {Text : Type u} {FormulaNF : Type v} [DecidableEq FormulaNF]
    (T : VocabularyTest Text FormulaNF) (text : Text) : VocabularyStatus :=
  if T.translate (T.strongSubst text) = T.translate (T.neutralSubst text) then
    .proofAnchored
  else
    .exceedsTranslation

theorem proofAnchored_not_exceeds {Text : Type u} {FormulaNF : Type v}
    (T : VocabularyTest Text FormulaNF) (text : Text) :
    ProofAnchored T text → ¬ ExceedsTranslation T text := by
  intro h hne
  exact hne h

theorem exceeds_not_proofAnchored {Text : Type u} {FormulaNF : Type v}
    (T : VocabularyTest Text FormulaNF) (text : Text) :
    ExceedsTranslation T text → ¬ ProofAnchored T text := by
  intro hne h
  exact hne h

instance proofAnchoredDecidable {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    Decidable (ProofAnchored T text) := by
  unfold ProofAnchored
  exact inferInstance

instance exceedsTranslationDecidable {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    Decidable (ExceedsTranslation T text) := by
  unfold ExceedsTranslation
  exact inferInstance

theorem vocabularyStatus_proofAnchored {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text)
    (h : ProofAnchored T text) :
    vocabularyStatus T text = .proofAnchored := by
  have heq : T.translate (T.strongSubst text) = T.translate (T.neutralSubst text) := h
  simp [vocabularyStatus, heq]

theorem vocabularyStatus_exceeds {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text)
    (h : ExceedsTranslation T text) :
    vocabularyStatus T text = .exceedsTranslation := by
  have hne : T.translate (T.strongSubst text) ≠ T.translate (T.neutralSubst text) := h
  simp [vocabularyStatus, hne]

theorem vocabularyStatus_proofAnchored_iff {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    vocabularyStatus T text = .proofAnchored ↔ ProofAnchored T text := by
  unfold vocabularyStatus ProofAnchored
  by_cases h :
      T.translate (T.strongSubst text) = T.translate (T.neutralSubst text)
  · simp [h]
  · simp [h]

theorem vocabularyStatus_exceeds_iff {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    vocabularyStatus T text = .exceedsTranslation ↔ ExceedsTranslation T text := by
  unfold vocabularyStatus ExceedsTranslation
  by_cases h :
      T.translate (T.strongSubst text) = T.translate (T.neutralSubst text)
  · simp [h]
  · simp [h]

theorem vocabularyStatus_not_both {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    ¬ (ProofAnchored T text ∧ ExceedsTranslation T text) := by
  rintro ⟨hanchored, hexceeds⟩
  exact proofAnchored_not_exceeds T text hanchored hexceeds

theorem vocabularyStatus_complete {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    ProofAnchored T text ∨ ExceedsTranslation T text := by
  by_cases h :
      T.translate (T.strongSubst text) = T.translate (T.neutralSubst text)
  · exact Or.inl h
  · exact Or.inr h

theorem vocabularyStatus_sound {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    match vocabularyStatus T text with
    | .proofAnchored => ProofAnchored T text
    | .exceedsTranslation => ExceedsTranslation T text := by
  unfold vocabularyStatus ProofAnchored ExceedsTranslation
  by_cases h :
      T.translate (T.strongSubst text) = T.translate (T.neutralSubst text)
  · simp [h]
  · simp [h]

theorem vocabularyStatus_cases {Text : Type u} {FormulaNF : Type v}
    [DecidableEq FormulaNF] (T : VocabularyTest Text FormulaNF) (text : Text) :
    (vocabularyStatus T text = .proofAnchored ∧ ProofAnchored T text) ∨
      (vocabularyStatus T text = .exceedsTranslation ∧ ExceedsTranslation T text) := by
  by_cases h : ProofAnchored T text
  · exact Or.inl ⟨vocabularyStatus_proofAnchored T text h, h⟩
  · have hexceeds : ExceedsTranslation T text := h
    exact Or.inr ⟨vocabularyStatus_exceeds T text hexceeds, hexceeds⟩

end Traceability

end ERIEC
