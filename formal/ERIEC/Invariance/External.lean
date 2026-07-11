namespace ERIEC
namespace Invariance

universe u v

/-- E5: external transitions transport along isomorphic state cores. -/
structure E5 {S : Type u} {Core : Type v} (stepExt : S → S → Prop)
    (core : S → Core) (Isomorphic : Core → Core → Prop) : Prop where
  transport : ∀ {s s' t}, Isomorphic (core s) (core s') → stepExt s t →
    ∃ t', stepExt s' t' ∧ Isomorphic (core t) (core t')

end Invariance
end ERIEC
