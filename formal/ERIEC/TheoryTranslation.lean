import ERIEC.Audit

namespace ERIEC

namespace TheoryTranslation

universe u v w x

/-- §20.1: a minimal institution-style theory interface. -/
structure Theory where
  Signature : Type u
  Sentence : Signature → Type v
  Model : Signature → Type w
  satisfies : {signature : Signature} → Model signature → Sentence signature → Prop

/-- A translation includes signature and sentence translation together with a
contravariant model reduct. -/
structure Translation (source target : Theory.{u, v, w}) where
  signature : source.Signature → target.Signature
  sentence : {s : source.Signature} →
    source.Sentence s → target.Sentence (signature s)
  reduct : {s : source.Signature} →
    target.Model (signature s) → source.Model s

/-- Satisfaction preservation is not inferred from a vocabulary map; it is an
explicit proof obligation. -/
def SatisfactionPreserving {source target : Theory.{u, v, w}}
    (translation : Translation source target) : Prop :=
  ∀ {signature} (model : target.Model (translation.signature signature))
      (sentence : source.Sentence signature),
    source.satisfies (translation.reduct model) sentence ↔
      target.satisfies model (translation.sentence sentence)

/-- A conservative translation additionally permits every source model to be
expanded to a target model with the same reduct. -/
def Conservative {source target : Theory.{u, v, w}}
    (translation : Translation source target) : Prop :=
  SatisfactionPreserving translation ∧
    ∀ {signature} (model : source.Model signature),
      ∃ expanded : target.Model (translation.signature signature),
        translation.reduct expanded = model

/-- Definition 20.1: the result class of one translated claim. -/
inductive TranslationResult where
  | structural
  | functional
  | bridge
  | untranslated
  deriving DecidableEq, Repr

/-! §20.2: independent guarantee axes. -/

inductive CoreGuarantee where
  | none
  | model
  | machineChecked
  deriving DecidableEq, Repr

inductive AuditGuarantee where
  | none
  | bounded
  | simulationSound
  | implementationLinked
  deriving DecidableEq, Repr

inductive ViabilityGuarantee where
  | none
  | recoverable
  | possibleLive
  | fairLive
  | boundedLive
  deriving DecidableEq, Repr

inductive GenerativeGuarantee where
  | none
  | observed
  | fresh
  | cofinal
  deriving DecidableEq, Repr

inductive TranslationGuarantee where
  | none
  | glossary
  | satisfactionPreserving
  | conservative
  deriving DecidableEq, Repr

/-- The product type prevents evidence on one axis from definitionally
upgrading another. The phenomenal axis has only the guarded value. -/
structure GuaranteeProfile where
  core : CoreGuarantee
  audit : AuditGuarantee
  viability : ViabilityGuarantee
  generative : GenerativeGuarantee
  translation : TranslationGuarantee
  phenomenal : MetaSelection.PhenomenalClaim := .notCertified
  phenomenal_guard : phenomenal = .notCertified := by rfl
  deriving Repr

theorem phenomenal_notCertified (profile : GuaranteeProfile) :
    profile.phenomenal = .notCertified :=
  profile.phenomenal_guard

/-- A machine-checked core alone leaves every other axis available at `none`;
there is no cross-axis promotion rule. -/
def coreOnly : GuaranteeProfile where
  core := .machineChecked
  audit := .none
  viability := .none
  generative := .none
  translation := .none

@[simp] theorem coreOnly_audit_none : coreOnly.audit = .none :=
  rfl

@[simp] theorem coreOnly_phenomenal_notCertified :
    coreOnly.phenomenal = .notCertified :=
  rfl

end TheoryTranslation

end ERIEC
