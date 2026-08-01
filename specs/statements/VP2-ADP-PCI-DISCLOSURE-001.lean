import ERIECPCI.Nondegenerate

namespace ERIECV2.Statement.VP2_ADP_PCI_DISCLOSURE_001

/-- 発行された証明書に対し、開示が PCI の必須開示項目を漏れなく含むことを述べる。
保証項目と非保証項目の双方についての完全性である。 -/
def Statement : Prop :=
  PCI.DisclosureComplete
    ERIECPCI.Nondegenerate.certificate
    ERIECPCI.Nondegenerate.disclosure

example : Statement :=
  ERIECPCI.Nondegenerate.disclosure_complete

end ERIECV2.Statement.VP2_ADP_PCI_DISCLOSURE_001
