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

証人: 富モデル（義務 1.6 強化系）が cofinal な `Φ_rich` を持つこと（VP-GEN-005 で履行）。

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

### VP-GEN-005 — 富モデル系譜の具体証人（cofinal Φ_rich、VP-GEN-003 の証人義務履行）

起票 2026-07-14（ユーザー承認済み・改訂順 A）。VP-GEN-003 の「証人: 別 VP・後続」を払う。
`ProliferationEvent` 上の具体的な系譜であって、意味論不変な富スコアが cofinal になる
（⇒ `lineage_stays_open_phi_rich` により FreshSem = 系譜は意味論的に開く）ものを構成する。

#### 設計上の障害 2 点と、それを避ける構成（statement の根拠）

1. **`Generation.phi_rich` は {0,1} 値**（[Generation.lean:44](../formal/ERIEC/Generation.lean#L44)）。
   `Cofinal q L` は「∀ bound, ∃ n, bound < q(系 n)」を要求するので、{0,1} 値の量は
   原理的に cofinal になれない。∴ 本 VP は phi_rich の cofinality を**主張しない**（不可能）。
   cofinal にするのは別の意味論不変スカラー（下記 score、蝶番濃度の代理）。
2. **アダプタ `dcToOpenSystem` は `Fast=Slow=Env=S` へ忘却する**
   （[Generation.lean:13](../formal/ERIEC/Generation.lean#L13)）。既存の静的富モデル族
   `parameterizedRichDC k` は状態型が全 k で共通（`RefState`）なので、翻訳後の
   OpenSystem が世代間で区別できず、いかなる意味論不変スコアも定数になる。
   ∴ 証人族は**富を状態型に運ぶ**必要がある: 第 n 世代の状態型と蝶番濃度をともに
   n+1 にする新しい有限 DC 族を `RefModel` に立てる。アダプタ自体を M を運ぶ形へ
   精緻化する案は certified な VP-GEN-001 の変更を要するため本 VP に含めない（別研究判断）。

#### 予約する Lean 宣言（namespace `ERIEC.RefModel`、新規ファイル `formal/ERIEC/RefModel/LineageWitness.lean`）

正確な型は codex が G0 で凍結（`ParameterizedRichReferenceWitness` の前例に倣い
witness structure + `Nonempty` 定理の形）。以下は claude 側の型スケッチ。

```
-- 系譜用の富 DC 族: 第 n 世代は状態型・蝶番濃度ともに n+1
-- （parameterizedRichDC の S=RefState 固定を S=Fin (n+1) に置き換えた変種）
def ERIEC.RefModel.richLineageDC (n : ℕ) : DC (Fin (n+1)) Unit Unit (Fin (n+1))

-- 隣接世代を結ぶ増殖射（E=Unit なので Branch は空 → branch_transport は空虚に成立、
-- phi_rich は両辺 0 → phi_rich_lax 成立。heritage/rank は witness データとして供給）
def ERIEC.RefModel.richLineageStep (n : ℕ) :
    Generation.ProliferationMorphism (richLineageDC n) (richLineageDC (n+1))

-- 選ぶ意味論: Fast 型の等濃 sem.rel a b :↔ Nonempty (a.Fast ≃ b.Fast)
def ERIEC.RefModel.cardSem : OpenEvolution.SemanticEquivalence

-- 選ぶスコア: score sys := Nat.card sys.Fast（cardSem 不変は定義から）
def ERIEC.RefModel.cardPhiRich : Generation.PhiRich cardSem

-- 証人 structure（前例 ParameterizedRichReferenceWitness に倣う）
structure ERIEC.RefModel.RichLineageWitness where
  lineage : OpenEvolution.Lineage Generation.ProliferationEvent
  system_eq : ∀ n, lineage.system n = Generation.dcToOpenSystem (richLineageDC n)
  -- スコアと DC 側蝶番濃度の整合（score が蝶番濃度の忠実な代理であることの証明義務）
  score_eq_hinge_card : ∀ n,
    cardPhiRich.score (lineage.system n)
      = (Hinge.Act (richLineageDC n).rhoRel (richLineageDC n).sigmaRel
          (richLineageDC n).kappa (richLineageDC n).epsilon (richLineageDC n).s).ncard
  cofinal : OpenEvolution.Lineage.Cofinal cardPhiRich.score lineage

-- 台帳照合対象（G1）: 証人の存在
theorem ERIEC.RefModel.rich_lineage_reference_model : Nonempty RichLineageWitness

-- 系: 系譜は意味論的に開く（VP-GEN-003 の instantiation を実モデルで発火）
theorem ERIEC.RefModel.rich_lineage_freshSem (w : RichLineageWitness) :
    OpenEvolution.Lineage.FreshSem cardSem w.lineage :=
  Generation.lineage_stays_open_phi_rich cardSem w.lineage cardPhiRich w.cofinal

-- 系: 最終的周期性の排除（freshSem_not_eventuallyPeriodicSem の発火）
theorem ERIEC.RefModel.rich_lineage_not_eventuallyPeriodic (w : RichLineageWitness) :
    ¬ OpenEvolution.Lineage.EventuallyPeriodicSem cardSem w.lineage
```

#### 未確定事項との関係（明示・混在させない）

- **Φ_rich 重みづけ（memo §11 未確定 1）は本 VP で固定しない**。`cardPhiRich` は
  「意味論不変スカラーを 1 つ供給する existential 証人」であり、Φ_div 成分（蝶番濃度）
  の代理。ユーザーが (Φ_depth, Φ_div, Φ_level) の合成を確定したら `PhiRich` バンドル
  を差し替えるだけで本 statement の形は保たれる。
- 証人族は E=Unit（分岐なし・phi_rich=0）で cofinality を払う設計。「分岐あり
  （phi_rich=1）かつ cofinal」の強化版は VP-RICH-001/002 の Branch 実装後に別途
  検討可能だが、本 VP の義務ではない。

#### Julia 側（有限接頭辞チェッカ）

`check_rich_lineage_cofinal(N, bound)`: 世代 0..N について (i) 隣接増殖射 certificate、
(ii) score(系 n) = n+1、(iii) bound < N+1 なる bound に対し score が bound を超える世代の
実在、を検査。無限主張自体は Lean 側のみが払う（既存の arbitrarily_large 系 VP と同じ分界）。

## 実装順序（codex）

1. VP-GEN-001（adapter/翻訳 witness）を先に固定 — 実装側はこれが無いと動けない（codex 要請）。
2. VP-GEN-002（増殖射）。
3. VP-GEN-003（開放性の instantiation）。
4. VP-GEN-004（世代間遺伝）。
5. VP-GEN-005（富系譜の具体証人。1〜4 は certified 済みなので単独で着手可）。

## 不変条項チェック（設計段階・偽C）

- 層分離: 増殖射はメタ層 Hom(𝓘)。対象層 M1〜M4 に対象・公理を足さない。DC はパラメータ。✓
- M4: 子は低階数で再誕、D に到達可能終対象なし（M4b）、外部 set point 注入なし（M4a）。✓
- Σ-purity: `𝒮` は増殖射集合の上で選択するが選択値を個体トレースへ write-back しない。✓
- 灯り: `phenomenal_claim = :not_certified` 不接触。増殖しても各対象は not_certified。✓
- 同一視の禁止: `DC⇒viable` は一方向 translation witness のみ。逆向き禁止を維持。✓

VP-GEN-005 固有:

- 層分離: 証人族 `richLineageDC` は対象層の**具体モデル構成**（RefModel の前例どおり）で
  あり、対象層への公理追加ではない。系譜・スコアはメタ層。✓
- M4: 系譜は ω 型で終対象（極限対象）を**足さない**。スコアの非有界成長は witness 族の
  事実であって、個体内に最大化勾配・set point を注入しない（各世代の DC は独立に M1〜M4 充足）。✓
- 灯り: FreshSem は構造的主張。`phenomenal_claim = :not_certified` 不接触。✓
