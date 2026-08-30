# 構造修正の手順書 — v3（MX 決定反映・2026-08-30）

状態: **ユーザー決定反映済み。codex レビュー待ち → その後に実装。**
v2 からの変更: MX 第三段の採用（モデル族指定として）により**経路が (Y) 案C に確定**。
第一段・第二段は選好不要のため独立に先行できる。凍結段の内容を具体化。

決定の全文は `specs/mx-layer-reconsideration.md`。

---

## 0. 確定事実（codex 監査済み）

1. `phi_rich = if RichnessWitness dc then 1 else 0`（`formal/ERIEC/Generation.lean:44`）。値域 {0,1}。
2. `Cofinal q L = ∀ bound, ∃ n, bound < q (L.system n)`（`formal/ERIEC/Lineage.lean:56`）。
   `Cofinal phi_rich L` は型不一致で書けない（`phi_rich : DC → Nat`、`L.system : OpenSystem`）。
   正確には「DC 表現を介した任意の {0,1} 値 score は `bound := 1` で Cofinal 不成立」。
3. `phi_rich` は開放性定理に入力されていない。core での構造的用途は `phi_rich_lax` のみ。
   catalog / ledger が認証しているのは**一般版** `lineage_stays_open` であり、
   `lineage_stays_open_phi_rich` は catalog 未登録。
4. 空洞は score だけでなく **`SemanticEquivalence` も呼び出し側供給**。
5. `cardPhiRich.score = Nat.card system.Fast`（サイズであって豊穣度ではない）。
   **決定的反例**: `richLineage` は全世代 `phi_rich = 0`・`branch_transport` 空虚に真でありながら
   `cardPhiRich` は cofinal。
6. `dim Wld` は現行 `OpenSystem` 上で定義不能（`dcToOpenSystem` の情報忘却）。
7. MX-4（公平性型）は MX-2（予測不能性）と両立。同形は `OpenFrame.fair` / `Recurrent` / `FairLive`。
8. 「phi_rich 修理が MX-4 に先行」は安全な工程順だが**論理依存ではない**。
   MX-4 の概念設計は並行可能。段1 に依存するのは FreshSem へ接続する証明のみ。

---

## 段 A. MX 第一段・第二段（選好不要・先行可）

**段1 以降に依存しない。** 既存基準の適用であり、ユーザー決定を要さない。

**A-1 証書の衛生**: いかなる証書も、永続性・最終性・無条件の跨文脈存続を主張しないことを検査する。

**訂正（codex 監査 2026-08-30）**: 「新しい語彙を要さない」は誤り。`failure_mode_review` は
**パケットのサイドカーを検査するだけ**であり、159 件の catalog・保証文面・runtime certificate には
束縛されない。永続性・最終性・跨文脈無条件性を機械的に拒否するには、
**証書の universe と構造化された enum / flags** が要る。同型の機構で足りるという見立ては誤りだった。

**A-2 射程の語彙**: 証書に天候指標を持たせファイバー局所性を記録する。これも小変更ではない。

- **命名は必須で変更**: `T′` は本 repo で感覚運動作用素 `T_prime` と理論拡張の双方に既使用。
  **`weather_id` / `context_id` 等へ改名する**。
- **既存 scope の流用禁止**: `checker-semantic-manifest` は 159 契約全件に
  scope / assumptions / guarantee を持つが、その scope は**有限 checker 入力範囲**であって
  天候 scope ではない。overloading してはならない。
- **二層に分離して凍結**: `CertifiedContract` は普遍 Lean 宣言の catalog であり、
  具体的な天候は instance envelope の属性である。したがって
  **catalog 側 `scope_kind` と instance 側 `context_id` を分ける**。
- **影響面（codex 列挙）**: Lean TSV schema / version、Julia parser / `CertifiedContract` /
  summary / envelope / dependency graph、159 行 manifest の整合、claim ledger 91 件中
  contract 付き 38 件、legacy ledger と model-evaluation の binding、後方互換、
  missing / unknown / mismatch の負例。

**要ユーザー決定**: 段A の対象を「**全証書**」とするか「**certified envelope の境界のみ**」とするか。
codex がパケット化の前提として固定を求めている。

**反証条件**: 永続性・最終性を主張する合成証書を作り、A-1 の検査が実際に落ちること。
期待した違反符号**だけ**が返ること（`mutation_check.jl` と同じ厳格さ）。

---

## 段 0.5. 凍結（claude 起草 + ユーザー承認）— 段1 の前提

経路が (Y) に確定したため、凍結すべき内容が具体化した。

1. **豊穣度の意味**: 系譜における**新規分岐の個数**（branch novelty）。
   `Φ_div` を系譜の時間方向へ延ばしたもの。確定済み（`mx-layer-reconsideration.md` §5）。
2. **正準 score の exact statement**: 何をもって「新規」とするか。意味的等価類を法とした
   新規性か、Medium 内の像の一致で判定するか。
3. **許す `SemanticEquivalence` のクラス**: caller 任意を止めるための制限。
4. **`Branch` の同一性**: codex 指摘 (vii) — `Branch` は現在 `Prop` であり branch identity を
   持たない。数えるには識別子が要る。**案C の中心課題**。
5. **対象拡充の型**: `OpenSystem` に何を足すか（(Y) では Wld は不要だが、
   分岐識別のために必要な構造は別途確定が要る）。
6. **固定名一覧**。

**追加項目（codex 監査 2026-08-30。`Branch` の同一性は中心課題だが唯一ではない）**:

- (a) `Branch` の `Prop` を witness / event データへ格上げすること。加えて、
  **世代ごとに M 型が変わる間の cross-generation identity / transport**。
- (b) novelty 同値が setoid / congruence を持ち、score が**代表元に依存しない**こと。
- (c) prefix の累積、非隣接の重複排除、identity / composition の coherence。
- (d) finite / DecidableEq / quotient について、Lean の定理と Julia の実行表現が一致すること
  （`Nat.card` が infinite で 0 になる罠の回避）。
- (e) enriched object を対象層ではなく**メタ側のどこに置くか**。あわせて
  `ProliferationEvent` が `Nonempty` witness を隠している問題の解決。
- (f) `MX-4 → 正準 novelty の Cofinal → FreshSem` の**方向と量化子**、および
  Σ-purity（no write-back）との整合。

**成果物**: 凍結文書 1 本 + **必要な型変更・API 変更・新規証明の件数表**。
件数表を見てユーザーが進退を決める（v1 の「見積りが大きければ停止」という主観的条件は撤回）。

---

## 段 1. 尺度の修理（実装・codex）— 凍結後

経路 (Y) = 案C。必要な新規開発（codex 見積り）:

- branch-to-Medium 写像。現 `parentHeritage` / `childHeritage` は `Config → Heritage` であり
  分岐識別子への写像ではない。
- 共有・輸送可能な Medium。`Heritage` は `ProliferationMorphism` ごとに変えられる。
- identity / composition / pullback。
- 有限性・DecidableEq と新規分岐数。
- sem 不変証明。
- 参照モデルと Julia 契約。
- `ProliferationEvent` の witness が existential に隠れている問題の解消（codex 指摘 (iii)）。

**反証条件（正例 1 本では不十分）**:

- 正準 score の**非任意性**（呼び出し側が差し替えられない配線であること）。
- sem 不変性の定理。
- **link theorem**: score が凍結文書の「豊穣度の意味」を実際に測っている証明。
- **陰性条件**: branch-free の `richLineage` 型系譜を豊穣 cofinal として**受理しない**こと。
- **陽性条件**: `branchedRichLineage` 等の非自明例で cofinal が立つこと。
- Julia 契約: 現 checker は regression_only で FreshSem を検証しない（codex 指摘 (v)）。
  修理後に名乗る relation は checker-strengthening の共有規則に従い別途判定する。

---

## 段 2. 空洞の掃除（実装・codex）— 段1 後

- `phi_rich_lax` / `branch_transport` の冗長解消。**注意（codex 指摘 (vi)）**: 両者の同値は
  manifest の記述だけで Lean の同値定理は無い。解消の前に同値を定理化するか独立性を確認する。
- 残す field ごとの nonredundancy test。
- `LineageWitness` の `Unit` / `True` 自明充足の扱い（非自明化 vs 意図的最小性の注記）。
  **ユーザー決定**。参照モデルの最小性は無矛盾性証人としての価値でもあるため、
  一律の非自明化は誤りうる。
- `GenerationWitness` 下流未利用・rank fields 定理未利用は、削除でなく**可視ギャップ**として
  台帳へ起票（**起票は claude 担当**）。

---

## 段 3. MX-4 の形式化 — 概念設計は並行可

- 概念設計（`OpenFrame.Fair` と同形、底圏への公平性、モデル族指定としての書き方）は
  段1 と**並行可**。
- FreshSem へ接続する証明のみ段1 完了に依存。
- **反証条件（codex により具体化・2026-08-30 追加訂正）**: `FairRealizable` 型
  （§17.8 / Lean の `∀s, init s → ∃ fair execution`）と同形なら整合する。ただし
  **`init = ∅` ではこれ自体が空虚に成立する**ため、`InitInhabited`（`∃s, init s`）を別途必須化する。
  これは族の `Nonempty` とは別条件であり、混同しない。
- **循環の禁止**: `OpenFrame.fair` は caller-supplied predicate（`OpenDynamics.lean:169`）である。
  結論を `fair` の定義に埋め込む循環を防ぐため、**scheduler / enabled-edge 由来の非循環な
  fairness と具体 witness** が要る。
- **defer**: MX-2 の予測不能性を壊さない独立モデルの構成は、MX-2 の exact predicate が
  未凍結のため現時点では判定できない。凍結後に回す。
- MX-4 からの帰結が**条件付き**であることの明示。
- Lenia による具体化: カーネル引数の走行中変更が底圏の射の実験系になる。

---

## 段 4. 記録の整備（文書・claude）— 並行可

- 三分割表への `viable ≠ DC` 未証明の明記（`mx-layer-reconsideration.md` §2.1 に反映済み）。
- 台帳の失効状態（`revoked` / `superseded` 相当）は**独立別件**として起票のみ。
  現 `certification_status` は certified / uncertified のみで失効状態が無く、
  `certified_text_hash` は現文面への binding であって歴史的効力状態ではない。
- `GRP-DYN-5` 反証条件起草（`specs/falsification-draft-GRP-DYN-5.md`）は本手順と独立に継続。
- **完了の証拠**: 文書作業には機械ゲートが無いため、各項目の完了を
  「該当ファイルの該当節を指せること」で定義する。

---

## 依存グラフ（v3）

```
段A（第一段・第二段）── 独立・先行可
段0.5（凍結）→ 段1（案C）→ 段2（掃除）
                    └→ 段3 の FreshSem 接続証明
段3 の概念設計 ── 並行可
段4（記録）  ── 並行可
```

---

## codex レビューで挙がった見落とし（7 件・取り込み済み）

(i) `SemanticEquivalence` も caller 任意 → §0-4、段0.5-3。
(ii) `dcToOpenSystem` の情報忘却 → §0-6。
(iii) `ProliferationEvent` の witness 隠蔽 → 段1。
(iv) certified は一般定理で特殊化は未登録 → §0-3。
(v) Julia checker は regression_only で FreshSem を検証しない → 段1 の Julia 契約。
(vi) `phi_rich_lax` ↔ `branch_transport` の同値は Lean 定理なし → 段2。
(vii) `Branch` は `Prop` で branch identity を持たない → 段0.5-4（案C の中心課題）。
