# 増殖射（誕生半球）設計 spec — §11-3

出典: `category/erie_c_axiom_categorical_memo.md §11-3`（増殖の射の定義・研究判断）。
2026-07-08 のユーザー批准を受けて起票。設計は claude 役、Lean 実装は codex 役。

## 目的

対象層が導出するのは維持/崩壊の否定形法則のみ（無条件法則は極小モデルで上限が決まる）。
肯定形（誕生・豊かさ）は **メタ層の定理 + 対象層の証人** で払う。本 spec は誕生半球を、
既存の維持/崩壊法則から浮かせずに（`viable ≠ DC` を保ったまま）建てる。

## 批准済み研究判断（2026-07-08）

1. **生殖的分岐**を先に形式化（発生的遷移 ontogeny は後続）。
2. `DC ⇒ viable` は一般定理でなく **一方向 translation witness**（新規構成物）として実現。
   逆向き `viable ⇒ DC` は「同一視の禁止」条項により依然禁止。
3. 世代間の豊かさ遺伝は A-6 単段（`hinge_branch_pump`）とは **別 statement**。
   まず単段 + 増殖射の骨格を固める。

## アーキテクチャ（codex 案採用）

`GenEvent` を `DC→DC` に持ち替えない。代わりに **DC 認証ユニットを OpenSystem へ忘却する
adapter + 一方向 translation witness** を新設し、既存の `Lineage` / `OpenEvolution`
（`viable` 世界）をそのまま再利用する。これにより 2 層のギャップを閉じずに一方向で跨ぐ。

### 既存資産（再利用）

- `ERIEC.OpenEvolution.OpenSystem`（`Fast/Slow/Env/step`）、`Config`、`ViableSystem`
  （`viable` + `step_closed`）— [OpenEvolution.lean](../formal/ERIEC/OpenEvolution.lean)
- `ERIEC.OpenEvolution.Lineage.GenEvent`、`FreshSem`、`Cofinal`、
  `cofinal_implies_freshSem`、`freshSem_not_eventuallyPeriodicSem`（証明済み）
  — [Lineage.lean](../formal/ERIEC/Lineage.lean)
- `ERIEC.OpenEvolution.GenerationWitness`（viability/heritage をパラメータ化）
- `ERIEC.OpenEvolution.ProducesRicher` / `richer_offspring_reachable`（到達可能性型）
- `ERIEC.DC`（`alphaRel/sigmaRel/piRel/rhoRel/kappa/epsilon/boundary/s` +
  `hSelf/hSMC/hAct/hBound`）— [DC.lean](../formal/ERIEC/DC.lean)
- `ERIEC.Richness.hinge_branch_pump`（A-6・certified）— 遺伝契約の証人
- `ERIEC.Grading.RankedClosure` / `sig2`（階数付き再誕の制約に使用）

### 新設が必要な 3 点（codex 見立て）

DC の 4 フィールドから `viable` をそのまま落とす定義は存在しない。最低限:

1. 局所時間付きで DC ユニットを `OpenSystem` に読む forgetful/translation。
2. その上の `viable` 述語。
3. `step_closed` に相当する証人。

## 予約する Lean 宣言（namespace `ERIEC.Generation`）

正確な型は codex が実装内部の符号化choiceに合わせて確定する（G0 で statement 凍結）。
以下は claude 側の型スケッチ（署名案）。

### VP-GEN-001 — DC→OpenSystem 翻訳 witness

```
-- DC 認証ユニットを開放系へ忘却する adapter（局所時間つき）
def ERIEC.Generation.dcToOpenSystem {M E C S : Type*} (dc : DC M E C S) :
    OpenEvolution.OpenSystem
-- その上の viable 述語
def ERIEC.Generation.dcViable {M E C S : Type*} (dc : DC M E C S) :
    OpenEvolution.Config (dcToOpenSystem dc) → Prop
-- 一方向 translation witness: DC から ViableSystem を構成（step_closed 証明を含む）
def ERIEC.Generation.dcViableTranslation {M E C S : Type*} (dc : DC M E C S) :
    OpenEvolution.ViableSystem
```

規律: `viable ⇒ DC` の逆向きは作らない。これは一方向のみ。

### VP-GEN-002 — 増殖射 ProliferationMorphism（メタ層 structure）

`DC→DC` 単体でなく、`GenerationWitness` の拡張として:

```
structure ERIEC.Generation.ProliferationMorphism where
  sourceDC : DC ...          -- 親（DC 認証ユニット）
  targetDC : DC ...          -- 子
  toOpenParent : OpenEvolution.OpenSystem   -- dcToOpenSystem sourceDC
  toOpenChild  : OpenEvolution.OpenSystem   -- dcToOpenSystem targetDC
  gen : OpenEvolution.Lineage.GenEvent toOpenParent toOpenChild  -- 生成事象
  heritage : ...             -- GenerationWitness 由来の遺伝関係
  -- M4 整合な再誕: 子の階数を w* 以下に束ねる witness 側制約（閉包公理はいじらない）
  parentRank : W
  childRank  : W
  childRank_le_wstar : childRank ≤ wstar
  heritage_lax : Φ_rich targetDC ≥ Φ_rich sourceDC  -- 分岐点があるとき strict
```

規律チェック: メタ層 Hom(𝓘)。対象層に公理追加なし（DC はパラメータ）。子は低階数で再誕
（R2′ と無矛盾、M4b の終対象を作らない）。`heritage_lax` は witness 側制約で強制しない
（strict を全モデルに課すと退化モデルで反例）。

### VP-GEN-003 — 「系譜は開く」法則の DC 系譜への instantiation

`cofinal_implies_freshSem` を、`GenEvent := 増殖射が誘導する生成事象`、
`q := Φ_rich`（意味論不変な構造量）にインスタンス化。

```
theorem ERIEC.Generation.lineage_stays_open ... :
    -- Φ_rich が cofinal な DC 系譜は FreshSem（意味論的に新規な系が無限に現れる）
    Cofinal Φ_rich L → FreshSem sem L
```

証人: 富モデル（義務 1.6 強化系）が cofinal な `Φ_rich` を持つこと（別 VP・後続）。

### VP-GEN-004 — 世代間の豊かさ遺伝（A-6 単段の持ち上げ・別 statement）

決定 3 により A-6 とは分離。増殖射に沿って親の蝶番分岐内容が子の νΘ/Φ_rich に
運ばれる lax 単調性。単段証人は `hinge_branch_pump`。

```
theorem ERIEC.Generation.richness_inherits_generational
    (f : ProliferationMorphism) ... :
    -- 親に蝶番分岐点があれば子の Φ_rich は親以上（分岐点ぶん strict）
    (∃ m ∈ Act(sourceDC), Branch sourceDC.alphaRel m) →
      Φ_rich f.targetDC > Φ_rich f.sourceDC   -- あるいは ≥、遺伝契約の採り方に従う
```

## 実装順序（codex）

1. VP-GEN-001（adapter/翻訳 witness）を先に固定 — 実装側はこれが無いと動けない（codex 要請）。
2. VP-GEN-002（増殖射）。
3. VP-GEN-003（開放性の instantiation）。
4. VP-GEN-004（世代間遺伝）。

## 不変条項チェック（設計段階・偽C）

- 層分離: 増殖射はメタ層 Hom(𝓘)。対象層 M1〜M4 に対象・公理を足さない。DC はパラメータ。✓
- M4: 子は低階数で再誕、D に到達可能終対象なし（M4b）、外部 set point 注入なし（M4a）。✓
- Σ-purity: `𝒮` は増殖射集合の上で選択するが選択値を個体トレースへ write-back しない。✓
- 灯り: `phenomenal_claim = :not_certified` 不接触。増殖しても各対象は not_certified。✓
- 同一視の禁止: `DC⇒viable` は一方向 translation witness のみ。逆向き禁止を維持。✓
