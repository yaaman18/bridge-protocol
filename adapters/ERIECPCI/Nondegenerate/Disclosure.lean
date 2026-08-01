import ERIECPCI.Nondegenerate.Audit
import ProofCarryingIntersubjectivity.Disclosure
import ProofCarryingIntersubjectivity.DisclosurePresentation

namespace ERIECPCI.Nondegenerate

def verdict : PCI.RepresentationVerdict manifest :=
  .inadequate counterexample

def certificate : PCI.Certificate signature :=
  PCI.issueCertificate ⟨1⟩ manifest (.representation verdict)

def guaranteedMetadata : PCI.MetadataSidecar where
  reference := ⟨"eriec-pci-nondegenerate-guaranteed"⟩
  languageTag := "en"
  displayName := "Guaranteed result"
  description :=
    "Membership in the absorbing region is not identifiable from observations in this practice. " ++
    "This is the same fact as ERIE-C nondegINS, proved in both directions by corresponds_to_nondegINS."
  sources := ["ERIECPCI.Nondegenerate.corresponds_to_nondegINS"]
  version := ⟨"en-v1"⟩

def assumptionsMetadata : PCI.MetadataSidecar where
  reference := ⟨"eriec-pci-nondegenerate-assumptions"⟩
  languageTag := "en"
  displayName := "Audit assumptions"
  description :=
    "The scope contains every Boolean state. The accepted evidence consists of positive items for both Boolean occurrences. " ++
    "The target policy requires the target predicate to be nontrivial on the scope. The provenance policy requires the adapter actor, adapter rule, and ERIE-C reference-model provenance. " ++
    "The candidate is ERIE-C's nondegenerate reference model."
  sources :=
    [ "ERIECPCI.Nondegenerate.practice",
      "ERIECPCI.Nondegenerate.evidence",
      "ERIECPCI.Nondegenerate.admissibility",
      "ERIECPCI.Nondegenerate.candidate" ]
  version := ⟨"en-v1"⟩

def disclosureSidecars : List PCI.MetadataSidecar :=
  [guaranteedMetadata, assumptionsMetadata]

def disclosure : PCI.Disclosure certificate where
  guaranteedHead := .representationVerdictRecorded .inadequate
  guaranteedTail :=
    [ .targetNotIdentifiableOnScope,
      .adapterSpecific guaranteedMetadata.reference ]
  assumptions := [.adapterSpecific assumptionsMetadata.reference]
  notGuaranteedHead := .perturbationCoverageIsExternalAttestation
  notGuaranteedTail :=
    [ .positiveGateExampleIsMinimal,
      .verdictRelativeToTargetPolicy
        certificate.manifest.admissibility.policyRef,
      .candidateClassIsVersionPinned,
      .observationDoesNotSeparateScopeStates ]

theorem disclosure_complete :
    PCI.DisclosureComplete certificate disclosure := by
  constructor
  · intro item mandatory
    have item_eq :
        item = .representationVerdictRecorded .inadequate := by
      simpa [PCI.mandatoryGuaranteed, certificate,
        PCI.issueCertificate, verdict] using mandatory
    subst item
    simp [disclosure, PCI.Disclosure.guaranteed]
  · intro item mandatory
    simp [PCI.mandatoryNotGuaranteed] at mandatory
    rcases mandatory with rfl | rfl | rfl | rfl
    all_goals simp [disclosure, PCI.Disclosure.notGuaranteed]

def renderedCertificate : List String :=
  PCI.renderCertificate disclosureSidecars disclosure

end ERIECPCI.Nondegenerate
