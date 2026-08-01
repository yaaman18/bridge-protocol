import ERIECPCI.Nondegenerate

namespace ERIECV2.Statement.VP2_ADP_PCI_NOBUNDLE_001

/-- 非退化参照模型を PCI の監査マニフェストへ写したとき、適合束が存在しないことを述べる。
否定的主張であり、ERIE-C 側の主張を強めない。 -/
def Statement : Prop :=
  ¬ Nonempty (PCI.AdequacyBundle ERIECPCI.Nondegenerate.manifest)

example : Statement :=
  ERIECPCI.Nondegenerate.no_adequacy_bundle

end ERIECV2.Statement.VP2_ADP_PCI_NOBUNDLE_001
