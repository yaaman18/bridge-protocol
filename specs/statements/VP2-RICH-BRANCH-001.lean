import ERIEC.Adjunction

/-!
VP2-RICH-BRANCH-001 (draft) — 分岐点述語 `Branch`。

台帳 A-6 / VP-RICH-001。対象 decl: `ERIEC.Richness.Branch`
(formal/ERIEC/Richness.lean — 未作成。証明担当 codex が本型で実装する)。

`2 ≤ |α(m)|` の Set 版。剛性定理(v5.1 定理 1.3)の証明中の場合分け
`|α(a)| ≥ 2` を述語として抽出したもの。非退化性の原子であり、
公理ではなく分類子 [DEF](E1 不採用決定・公理メモ §11-2 参照)。
-/

namespace ERIECV2.Statement.VP2_RICH_BRANCH_001

/-- 分岐点: `m` の作動像が相異なる二元を含む。 -/
def Branch {M E : Type*} (alphaRel : M → Set E) (m : M) : Prop :=
  ∃ e₁ e₂ : E, e₁ ∈ alphaRel m ∧ e₂ ∈ alphaRel m ∧ e₁ ≠ e₂

end ERIECV2.Statement.VP2_RICH_BRANCH_001
