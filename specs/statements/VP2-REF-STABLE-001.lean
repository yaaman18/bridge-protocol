import ERIEC.RefModel

namespace ERIECV2.Statement.VP2_REF_STABLE_001

#check ERIEC.RefModel.StableReferenceWitness
#check (ERIEC.RefModel.stable_reference_model :
  Nonempty ERIEC.RefModel.StableReferenceWitness)

example : Nonempty ERIEC.RefModel.StableReferenceWitness :=
  ERIEC.RefModel.stable_reference_model

#print axioms ERIEC.RefModel.stable_reference_model

end ERIECV2.Statement.VP2_REF_STABLE_001
