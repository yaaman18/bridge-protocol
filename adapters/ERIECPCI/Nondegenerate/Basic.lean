import ERIEC.RefModel.Nondegenerate
import ProofCarryingIntersubjectivity.Representation

namespace ERIECPCI.Nondegenerate

open ERIEC RefModel
open PCI

inductive NondegenerateProvenance
  | eriecRefModel
  deriving DecidableEq, Repr

def signature : EvidenceSignature where
  Occurrence := Bool
  Observation := Unit
  Intervention := Unit
  Procedure := Unit
  Provenance := NondegenerateProvenance
  observationSetoid := equalitySetoid Unit

private def evidenceItem (state : Bool) : EvidenceItem signature where
  polarity := .positive
  about := fun occurrence => occurrence = state
  procedure := ()
  provenance := .eriecRefModel

def evidence : EvidenceSet signature where
  ItemId := Bool
  instFintype := inferInstance
  version := { serial := 1 }
  previous := none
  entry := evidenceItem
  accepted := fun _ => True
  provenance := .eriecRefModel

private def conflictPolicy : ConflictPolicy signature where
  sameCondition := fun left right => left.polarity = right.polarity
  refl := fun _ => rfl
  symm := fun equality => equality.symm
  trans := fun firstSecond secondThird => firstSecond.trans secondThird

def practice : Practice signature where
  version := { serial := 1 }
  scope := Set.univ
  evidenceAdoptionRule := fun item => item.polarity = .positive
  conflictPolicy := conflictPolicy
  provenance := .eriecRefModel

def model : CandidateModel signature where
  State := Bool
  observe := nondegObserve
  realizes := fun occurrence state => occurrence = state

end ERIECPCI.Nondegenerate
