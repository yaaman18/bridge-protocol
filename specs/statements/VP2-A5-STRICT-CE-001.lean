import ERIEC.InterfaceLinearization

open ERIEC.InterfaceLinearization

namespace ERIECV2.Statement.VP2_A5_STRICT_CE_001

#check (ERIEC.InterfaceLinearization.strict_naturality_fails_for_relationHom :
  ∃ (rel rel' : Unit → Set Unit) (h : RelationHom rel rel'),
    relationMatrix rel () () ≠
      relationMatrix rel' (h.onCodomain ()) (h.onDomain ()))

#print axioms ERIEC.InterfaceLinearization.strict_naturality_fails_for_relationHom

end ERIECV2.Statement.VP2_A5_STRICT_CE_001
