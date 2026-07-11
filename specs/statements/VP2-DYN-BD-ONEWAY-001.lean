import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_BD_ONEWAY_001

universe u

def Statement : Prop :=
  ∀ {S : Type u} (step : S → S → Prop) (viable : Set S)
    {s t : S},
    s ∈ ERIEC.Dynamics.K step viable → step s t →
      t ∉ ERIEC.Dynamics.downV step viable

example : Statement := by
  intro S step viable s t hs hst
  exact ERIEC.Dynamics.BdPair_oneway step viable hs hst

end ERIECV2.Statement.VP2_DYN_BD_ONEWAY_001
