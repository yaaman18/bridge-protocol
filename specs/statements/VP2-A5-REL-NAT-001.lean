import ERIEC.InterfaceLinearization

open ERIEC.InterfaceLinearization

namespace ERIECV2.Statement.VP2_A5_REL_NAT_001

#check (ERIEC.InterfaceLinearization.relationMatrix_reindex_natural :
  ∀ {M E M' E' : Type*}
    {rel : M → Set E} {rel' : M' → Set E'}
    (h : RelationIso rel rel'),
    Matrix.reindex h.codomain h.domain (relationMatrix rel) =
      relationMatrix rel')

#print axioms ERIEC.InterfaceLinearization.relationMatrix_reindex_natural

end ERIECV2.Statement.VP2_A5_REL_NAT_001
