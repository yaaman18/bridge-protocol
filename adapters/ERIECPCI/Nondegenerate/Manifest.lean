import ERIECPCI.Nondegenerate.Basic
import ProofCarryingIntersubjectivity.ClaimAuthorization
import ProofCarryingIntersubjectivity.Judgment

namespace ERIECPCI.Nondegenerate

open PCI

private def evidenceUsePolicy : EvidenceUsePolicy signature where
  version := { serial := 1 }
  usable := fun _ item => item.polarity = .positive

private def coverageRule : CoverageRule signature where
  Obligation := Bool
  nonempty := ⟨false⟩
  satisfies := fun obligation occurrence item =>
    occurrence = obligation ∧ item.polarity = .positive

private def perturbationPolicy : PerturbationPolicySpec where
  Dimension := Unit
  instFintype := inferInstance
  version := { serial := 1 }
  requiredDimension := fun _ => False
  domainRef := fun _ => { serial := 1 }

def claim : ClaimSpec signature where
  kind := .observational
  robustness := .reportOnly
  evidenceUsePolicy := evidenceUsePolicy
  coverageRule := coverageRule
  perturbationPolicy := perturbationPolicy
  normativeUseCondition := { serial := 1 }
  candidateObligationRef := { serial := 1 }

private def adapterActor : InterpretationActorRef := { serial := 1 }
private def adapterRule : InterpretationRuleRef := { serial := 1 }

private def candidateProvenance : InterpretationProvenanceData signature where
  creator := adapterActor
  rule := adapterRule
  practiceVersion := practice.version
  evidenceVersion := evidence.version
  createdAt := { serial := 1 }
  provenance := .eriecRefModel

def candidate : InterpretedCandidate signature claim where
  candidateVersionId := { serial := 1 }
  model := model
  target := fun state => state ∈ ERIEC.RefModel.nondegRegion
  interpretationProvenance := candidateProvenance

def targetAccepted (data : CandidateTargetData signature claim) : Prop :=
  ∃ inside outside,
    StateInScope practice data.model inside ∧
    StateInScope practice data.model outside ∧
    data.target inside ∧ ¬ data.target outside

def provenanceAccepted (data : InterpretationProvenanceData signature) : Prop :=
  data.creator = adapterActor ∧
  data.rule = adapterRule ∧
  data.provenance = .eriecRefModel

def admissibility : AdmissibilityContext signature claim where
  coverageContext := { evidence, practice, claim }
  sameClaim := rfl
  provenanceAccepted := provenanceAccepted
  targetAccepted := targetAccepted
  policyRef := { serial := 1 }
  policyMatchesClaim := rfl

def candidate_admissible :
    CandidateAdmissible admissibility candidate where
  sound := {
    realizesAccepted := by
      intro itemId occurrence accepted inScope about positive
      exact ⟨occurrence, rfl⟩
  }
  reflective := {
    reflected := by
      intro occurrence state inScope realized
      refine ⟨occurrence, ?_, rfl, rfl⟩
      exact ⟨trivial, rfl, rfl⟩
  }
  interpretationVersion := ⟨rfl, rfl⟩
  provenance := ⟨rfl, rfl, rfl⟩
  claimSpecific := ⟨false, true,
    ⟨false, trivial, rfl⟩,
    ⟨true, trivial, rfl⟩,
    by change false = false; rfl,
    by change true ≠ false; decide⟩

def registry : CandidateRegistry signature claim where
  Id := Unit
  instFintype := inferInstance
  entry := fun _ => candidate

private def proposer : Proposer := ⟨⟨"eriec-pci-adapter"⟩⟩
private def authority : ClaimAuthority := ⟨⟨"eriec-pci-authority"⟩⟩

private def emptyBurden : ClaimBurdenLedger where
  counterexamples := []
  disagreements := []
  rejectedEvidence := []
  missingObligations := []

private def claimRegistry : ClaimRegistryVersion where
  EntryId := Unit
  instFintype := inferInstance
  serial := 1
  entry := fun _ => ⟨"eriec-nondegenerate-ins"⟩
  burden := fun _ => emptyBurden

private def claimClassification : TotalClaimClassification claimRegistry :=
  fun _ => .sameClaimLineage

private def registryInheritance :
    RegistryBurdenInheritance claimRegistry claimClassification emptyBurden where
  inherited := by
    intro id requires
    exact ClaimBurdenIncludes.refl emptyBurden

private def authorizedClaim : AuthorizedTargetClaim signature :=
  admitClaimRoot claim ⟨"eriec-nondegenerate-ins"⟩
    proposer authority (by decide) ⟨1⟩
    claimRegistry claimClassification emptyBurden registryInheritance

private def lineageRegistry : LineageRegistryVersion where
  EntryId := Unit
  instFintype := inferInstance
  serial := 1
  entry := fun _ => ⟨"eriec-nondegenerate"⟩

def manifest : AuditManifest signature where
  version := { serial := 1 }
  previous := none
  claim := authorizedClaim
  practice := practice
  evidence := evidence
  candidateClass := .registry registry
  admissibility := admissibility
  claimRegistryVersion := claimRegistry
  lineageRegistryVersion := lineageRegistry
  counterexampleLedgerVersion := { serial := 1 }
  ledgerHead := { serial := 1 }
  perturbationAttestationRef := { serial := 1 }

end ERIECPCI.Nondegenerate
