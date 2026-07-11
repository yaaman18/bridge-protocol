import ERIEC.DC

/-!
VP2-RICH-HINGE-PUMP-001 (draft) — 蝶番分岐の余帰納核への遺伝(単段版)。

台帳 A-6 / VP-RICH-002。対象 decl: `ERIEC.Richness.hinge_branch_pump`
(formal/ERIEC/Richness.lean — 未作成。証明担当 codex が本型で実装する)。

主張: `DC` のもと、蝶番 `Act` 上の分岐点 `m` について `α(m) ⊆ νΘ`
(系: `νΘ` は相異なる二元を含む)。

証明素材(見込み): `Closure.coinduction` + 直像の単調性のみ。hConv 非依存。
スケッチ: `m ∈ Act ⊆ σ★(ε(s))` より `α(m) ⊆ α★(σ★(ε(s))) = Θ(ε(s))`。
`dc.hSMC`(`ε(s) ⊆ Θ(ε(s))`)と単調性より `Y := ε(s) ∪ α(m)` は後不動点、
余帰納原理で `Y ⊆ νΘ`。
-/

namespace ERIECV2.Statement.VP2_RICH_HINGE_PUMP_001

open ERIEC

/-- VP2-RICH-BRANCH-001 の述語(本ファイルを自己完結にするための再掲。
実体は `ERIEC.Richness.Branch` に一本化する)。 -/
def Branch {M E : Type*} (alphaRel : M → Set E) (m : M) : Prop :=
  ∃ e₁ e₂ : E, e₁ ∈ alphaRel m ∧ e₂ ∈ alphaRel m ∧ e₁ ≠ e₂

/-- 主定理の正確な型: 蝶番上の分岐点の作動像は余帰納核に含まれる。 -/
def HingeBranchPump {M E C S : Type*} (dc : DC M E C S) : Prop :=
  ∀ m ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s,
    Branch dc.alphaRel m →
      dc.alphaRel m ⊆ Closure.nu (Hinge.T_prime dc.alphaRel dc.sigmaRel)

/-- 系(幅): 前提下で `νΘ` は相異なる二元を含む。 -/
def HingeBranchPumpWidth {M E C S : Type*} (dc : DC M E C S) : Prop :=
  ∀ m ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s,
    Branch dc.alphaRel m →
      ∃ e₁ e₂ : E,
        e₁ ∈ Closure.nu (Hinge.T_prime dc.alphaRel dc.sigmaRel) ∧
        e₂ ∈ Closure.nu (Hinge.T_prime dc.alphaRel dc.sigmaRel) ∧ e₁ ≠ e₂

end ERIECV2.Statement.VP2_RICH_HINGE_PUMP_001
