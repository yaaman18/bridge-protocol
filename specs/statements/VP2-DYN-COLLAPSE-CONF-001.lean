import ERIEC.Dynamics

namespace ERIECV2.Statement.VP2_DYN_COLLAPSE_CONF_001

open ERIEC.Dynamics

universe u v w

def Statement : Prop :=
  ∀ {C : Type u} {E : Type v} {W : Type w}
    [Finite C] [Finite W] [LinearOrder W] [OrderTop W]
    (family : ERIEC.Grading.RankedClosure W C)
    (theta : W → Set E → Set E) (drift : W → Set C → W)
    (threshold : W),
    R2Prime drift → threshold < ⊤ → ERIEC.Grading.sig2 family threshold →
    ∀ c0 : Conf C E W,
      ∃ n ≤ Nat.card W + Nat.card C, ∀ k, n ≤ k →
        (((upd family.op theta drift)^[k]) c0).kappa = ∅

example : Statement := by
  intro C E W _ _ _ _ family theta drift threshold r2 hThreshold hSig2 c0
  exact collapse_conf family theta drift r2 threshold hThreshold hSig2 c0

end ERIECV2.Statement.VP2_DYN_COLLAPSE_CONF_001
