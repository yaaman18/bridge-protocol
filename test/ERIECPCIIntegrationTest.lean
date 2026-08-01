import ERIECPCI.Nondegenerate

open ERIEC Dynamics RefModel
open PCI

example :
    ¬ Nonempty
      (AdequacyBundle ERIECPCI.Nondegenerate.manifest) :=
  ERIECPCI.Nondegenerate.no_adequacy_bundle

example :
    INS nondegObserve nondegRegion ↔
      Nonempty
        (MixedFiber
          (StateInScope
            ERIECPCI.Nondegenerate.practice
            ERIECPCI.Nondegenerate.model)
          ERIECPCI.Nondegenerate.model.observe
          ERIECPCI.Nondegenerate.candidate.target) :=
  ERIECPCI.Nondegenerate.corresponds_to_nondegINS

example :
    PCI.DisclosureComplete
      ERIECPCI.Nondegenerate.certificate
      ERIECPCI.Nondegenerate.disclosure :=
  ERIECPCI.Nondegenerate.disclosure_complete

example :
    PCI.DisclosureItem.observationDoesNotSeparateScopeStates ∈
      ERIECPCI.Nondegenerate.disclosure.notGuaranteed := by
  simp [ERIECPCI.Nondegenerate.disclosure, PCI.Disclosure.notGuaranteed]

example :
    ERIECPCI.Nondegenerate.renderedCertificate =
      PCI.renderCertificate
        ERIECPCI.Nondegenerate.disclosureSidecars
        ERIECPCI.Nondegenerate.disclosure :=
  rfl

example :
    ERIECPCI.Nondegenerate.renderedCertificate.head? =
      some "Certificate id: 1" := by
  decide
