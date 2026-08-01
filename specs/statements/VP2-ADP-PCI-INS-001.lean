import ERIECPCI.Nondegenerate

namespace ERIECV2.Statement.VP2_ADP_PCI_INS_001

/-- ERIE-C の観測不可識別性 `INS` と、PCI 側の混合繊維の存在が同値であることを述べる。
両向きの含意を主張する双方向命題であり、片側だけでは足りない。 -/
def Statement : Prop :=
  ERIEC.Dynamics.INS ERIEC.RefModel.nondegObserve ERIEC.RefModel.nondegRegion ↔
    Nonempty
      (PCI.MixedFiber
        (PCI.StateInScope
          ERIECPCI.Nondegenerate.practice
          ERIECPCI.Nondegenerate.model)
        ERIECPCI.Nondegenerate.model.observe
        ERIECPCI.Nondegenerate.candidate.target)

example : Statement :=
  ERIECPCI.Nondegenerate.corresponds_to_nondegINS

end ERIECV2.Statement.VP2_ADP_PCI_INS_001
