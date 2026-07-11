import ERIEC.InterfaceLinearization

open ERIEC.InterfaceLinearization

namespace ERIECV2.Statement.VP2_A5_REL_LAX_001

#check (ERIEC.InterfaceLinearization.relationMatrix_lax_natural :
  ∀ {M E M' E' : Type*}
    {rel : M → Set E} {rel' : M' → Set E'}
    (h : RelationHom rel rel') (m : M) (e : E),
    relationMatrix rel e m ≤
      relationMatrix rel' (h.onCodomain e) (h.onDomain m))

#print axioms ERIEC.InterfaceLinearization.relationMatrix_lax_natural

end ERIECV2.Statement.VP2_A5_REL_LAX_001
