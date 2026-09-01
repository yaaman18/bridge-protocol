# 構造修正の手順書 — v3（MX 決定反映・2026-08-30）

状態: **段0.5 凍結完了（2026-08-30）。段1 パケット作成へ。**
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

1b. **【確定・ユーザー決定 2026-08-30】比較の媒体を射のフィールドからパラメータへ移す。**
   現状 `ProliferationMorphism`（`formal/ERIEC/Generation.lean`）は
   `Heritage : Type u` と `heritageRelated : Heritage → Heritage → Prop` を**射のフィールド**として
   持つ。すなわち**各射が比較の媒体とその上の関係を自分で選べる**。この状態では、
   どの同一性基準を採っても射が自分に都合よく媒体を選べるため、新規性は自明に充足しうる。
   媒体と関係を系譜レベルの固定パラメータへ移す。これは同一性基準の選択に**先行して**必要であり、
   選択がどれになっても必要である（下記の構造的知見を参照）。

   **構造的知見（2026-08-30）**: 候補となる三つの同一性基準はいずれも、
   親と子で型が異なる（`M` と `M'` は無関係）ため**世代をまたぐ輸送を必要とする**。
   基準の選択は「輸送が何を保つか」の選択であって、輸送の要否の選択ではない。
   したがって媒体は不可避であり、パラメータ化は基準選択と独立に確定できる。
2. **【確定・ユーザー決定 2026-08-30】同一性の基準は案A（構造的同一性）。**
   固定された媒体の中で像が一致することをもって、二つの分岐を同じとする。
   採らなかった案とその理由:
   - 案B（既存の意味的同値 `sem.rel` の流用）: `sem.rel` は `OpenSystem` 上の関係であり
     分岐上の関係ではない。分岐へ持ち上げるのは実質**新しい関係を作ること**であり、
     「既存機構の再利用」という利点は見かけ倒し。名前だけ同じで中身が違うものを作る危険は
     `PhiRich.score` と `phi_rich` で既に踏んでいる。加えて `sem` 自体が呼び出し側供給で
     恣意性を相続する。
   - 案C（開く先で区別できない・作用的同一性）: 最もエナクティヴだが、`α(m)` は `E`、
     `α'(m')` は `E'` に住むため**輸送から逃げられない**。媒体の選択は避けられても
     媒体の必要性は避けられず、加えて粗さで新規性が潰れる危険を負う。

   **必須の負例（媒体の二つの退化を塞ぐ）**:
   - 粗すぎる媒体: 枝の無い系譜に対して新規性が正にならないこと。
   - 細かすぎる媒体: 単に名前を付け替えただけの系譜に対して新規性が増えないこと。
   どちらも型検査を通り、どちらも尺度を無意味にする。`cardPhiRich` の反例が一つで
   路線を潰したことに鑑み、先に用意する。

2b. **【確定・ユーザー決定 2026-08-30】累積を採る。**
   score は接頭辞全体にわたる**相異なる分岐の累積数**とする。親とだけ比較しない。
   世代 1 に現れ 2 で消え 3 で再出現した分岐を「新規」と数えないため。
   累積数は単調非減少で非有界になりうるので `Cofinal` と素直に噛む。
3. **許す `SemanticEquivalence` のクラス**: caller 任意を止めるための制限。
4. **`Branch` の同一性**: codex 指摘 (vii) — `Branch` は現在 `Prop`
   （`∃ e₁ e₂ ∈ α(m), e₁ ≠ e₂`、`formal/ERIEC/Richness.lean:8`）であり branch identity を
   持たない。数えるには部分型 `{m : M // Branch α m}` を作り、識別子を与える必要がある。
   **案A の中心課題**（v2 では案C と誤記していた）。

4b. **【未決】score の余域 — 無限分岐の扱い**
   `Nat.card` は無限集合で 0 を返すため、無限に分岐する系譜を最も貧しいと判定する。
   `cardPhiRich` 反例と同型の罠。
   **重要な技術的事実（2026-08-30）**: 素朴に余域を `ℕ∞` へ変えるのは**不可**。
   `Cofinal q L := ∀ bound, ∃ n, bound < q (L.system n)` は `bound := ⊤` を許すため、
   最大元を持つ余域では `Cofinal` が充足不能になる。
   これは `phi_rich` が {0,1} で `bound := 1` を超えられなかったのと**同型の失敗**であり、
   **上に頭がある余域はそれが何であれ `Cofinal` を殺す**。
   残る選択肢:
   - (i) `Cardinal`。最大元が無いので `Cofinal` は生きるが、Lean で重く、
     **Julia 側で表現できない**（検査器は有限復号の上でしか動かない）。
   - (ii) `ℕ` のまま、有限性を blanket 仮定でなく **score 定義に付随する証明義務**として置く。
     Julia は有限復号の上でのみ判定し `relation` にその強さを記録。
     無限分岐は「この尺度が覆わない範囲」として**可視ギャップに記録**する。
   - (iii) numeric score を経由せず、**分岐版 freshness を直接述べる**。
     余域の問題が丸ごと消えるが、`cofinal_implies_freshSem` を使えず新しい橋の証明が要る。
5. **【確定・ユーザー決定 2026-08-30】σ 越し制約を保つ。対象拡充ではなくメタ層に観測フレームを置く。**

   `OpenSystem` を拡張しない。対象層（M1〜M4）に構造を足さない。
   代わりにメタ層へ観測フレーム（仮称 `BranchObservation`）を置き、
   DC witness と `hConv` と正準の branch-to-Medium 写像を露出する。

   **なぜこれが σ 越しを破らないか（2026-08-30 の知見）**:
   `Adjunction.lean:95-98` の `ConvSystem` は
   `hConv : ∀ m e, e ∈ alphaRel m ↔ m ∈ sigmaRel e` を持つ。
   この双条件のもとで α は σ から**定義可能**であり、独立した情報を持たない。したがって

   ```
   BranchSigma (sigmaRel) (m) := ∃ e₁ e₂, m ∈ sigmaRel e₁ ∧ m ∈ sigmaRel e₂ ∧ e₁ ≠ e₂
   ```

   は **σ だけで書けている**。そして `hConv` のもとで
   `BranchSigma sigmaRel m ↔ Richness.Branch alphaRel m` が成り立つ（証明義務）。

   つまり観測フレームの役割は α を持ち込むことではなく、
   **α が σ に決定されていることを要求すること**である。要求が満たされる範囲でのみ
   分岐は σ 越しに観測できる。これで `Φ_rich` の「σ越しの観測のみから計算される」は保たれる。

   **記録すべき射程の制限**: `DC`（`DC.lean:6-18`）は `alphaRel` と `sigmaRel` を
   独立フィールドとして持ち **`hConv` を持たない**。したがって
   **すべての DC ユニットが観測フレームの対象になるわけではない**。
   `hConv` を満たさない系では分岐新規性は定義されない。これは隠さず可視ギャップとして記録する。

6. **固定名（codex 提案 2026-08-30 を採用）**:
   `BranchObservation` / `BranchImage` / `BranchFresh` / `BranchReflectingSem` /
   `branchFresh_implies_freshSem` / `FiniteBranchScore`。
   経路名は `BranchNoveltyRoute`、同一性基準名は `StructuralImageIdentity`。
   **「経路(Y)=案C」と「同一性=案A」は別軸であり名称が衝突しやすいため、以後は固定名を用いる。**

---

## 段0.5 への codex レビュー反映（2026-08-30）

**4b の訂正**: 私が挙げた選択肢 (i) `Cardinal` は**棄却**。`Cardinal` に最大元が無いのは正しいが
（Mathlib `Cardinal/Order.lean:344` の `NoMaxOrder`）、ℕ で添字づけられた列は
`Cardinal.sum` で上から抑えられる（同 :476-480 `le_sum`）。したがって `q : Nat → Cardinal` も
現 `Cofinal` を満たせない。**「最大元が無い」だけでは不十分**であり、必要なのは
**可算族が必ずしも上界を持たないこと**である。ℕ はこれを満たし `Cardinal` は完備すぎて満たさない。

**採用**: (iii) を理論の核（数を経由しない `BranchFresh`）、(ii) を有限 Julia 観測に限定する二層。
ただし `BranchFresh → FreshSem` の直接橋には、`sem.rel` が正準 branch-image 集合を
保存・反映する前提が要る。

**確定4項に残る穴（codex 指摘・未解決）**:
- (a) **【設計確定・生成元は未決】** 媒体を系譜パラメータへ上げるだけでは caller 任意性は残る。
  codex 提案の最小形: 系譜に固定された**関係保存な環境輸送** `τₙ : Eₙ ↪ Eₙ₊₁` と
  identity / composition の coherence を置く。Medium は `Σ n, Eₙ` を τₙ が生成する同値関係で
  割った quotient、各写像は quotient injection とする。
  これにより caller は Medium を差し替えられず、rename-only の系譜は同一化され、
  `Embedding` であることが粗い collapse を防ぐ。
  **私が要求した二方向の負例が、型の選択によって構造的に処理される点に注目する。**
  現行コードからは正準 Medium を生成できない（`ProliferationMorphism` は `E → E'` を持たず
  `branch_transport` は `∃ m'` のみ。`Invariance.KIso.hE : E ≃ E'` は関係保存だが
  `ProliferationMorphism` に接続されておらず、増大世代一般には強すぎる）。
  **【確定・ユーザー決定 2026-08-30】τₙ の採択規則は二段構え。**
  - **一般形**: τₙ は系譜レベルのデータとして与える。制約は `Embedding`（単射）であることと、
    identity / composition の coherence。射ごとではなく系譜ごとに固定されるため、
    射が自分に都合よく選ぶ経路は塞がれる。
  - **正準インスタンス**: Lenia および参照モデルでは**全世代が同じ環境型を共有し τ を恒等**とする。
    Lenia では全世代が同じ場に住むため環境型は共有され、媒体はほぼ自明化し、
    同一性は σ-繊維の素朴な集合等号になる。**実際に検査する範囲では恣意性が消える。**

  **未解決の危険（claude 指摘・要検証）**: `Embedding` + coherence は**粗い collapse は防ぐが
  細かすぎる分離は防がない**。悪意ある τ を選べば、旧世代の繊維像が新世代のどれとも一致せず、
  すべてが新規になって `Cofinal` が自明充足し、`FreshSem` が空虚に従う。
  すなわち私が要求した二方向の負例のうち、**「名前を付け替えただけの系譜で新規性が増えない」側は
  一般形では未処理**である。正準インスタンス（共有 E・τ = id）では環境が literally 同一なので
  この危険は生じない。
  **【codex 2026-08-30・凍結を再開】負例ゲートでは足りない。型に naturality を入れる。**
  負例ゲートは一般形の定理を保証しない。最小修正は
  `carryₙ : BranchCarrier n → BranchCarrier (n+1)` と
  `fiber_natural : τₙ ∘ BranchFiber b = BranchFiber (carryₙ b)` を**型に置く**こと。
  τ が隣接 `Embedding` だけなら identity / composition は反復写像から**証明する**のであって
  caller-supplied field にしない。

  **【訂正・codex 2026-08-30】exact な fiber 保存と §12.4 の関係は条件付きである。**
  私は当初「全域 carry は §12.4 と矛盾する」と書いたが、正確には
  **全域基礎要件なら矛盾、任意の追加契約なら整合**である。

  memo:296-307 は「M1〜M4 や生存圧だけから豊穣化を導出しない」と述べた直後に
  `ProducesRicher` を**追加契約**として導入している。**先例がすでにある。**
  したがって full carry を `ProliferationMorphism` や全 lineage の基礎要件にせず、
  **任意のメタ層 `BranchNoveltyRoute` の証書条件に限定**し、
  「**喪失を含む系譜は存在してよいが、この route の認証対象外**」と scope を明記すれば矛盾しない。
  対象層への公理追加でもない。

  **私が出した二つの第三案はいずれも棄却された（codex・理由付き）**:
  - τ の全称量化案: 許容クラスを定める正準データが存在しない。別 quotient を取るには
    stable environment ID / 内容由来 fingerprint / relation-preserving partial iso /
    loss justification のいずれかを**新しい信頼データ**として要する。
    現 `ProliferationMorphism` は `E → E'` すら持たず `branch_transport` は存在のみで生成元がない。
  - 喪失の明示データ化案: 部分 carry の定義域下界は任意の subset / mapping で水増しでき、
    全喪失も排除するため解決にならない。「定義域 := 実際に像保存される枝」と定義する案は
    τ の正準性を制約せず**循環**。

  **【確定・ユーザー決定 2026-08-30】案(2) を採用**:
  - **(1) は棄却**。full carry を任意証書の条件にしても、能力喪失を含む系譜が route の
    認証対象外になるため、今回求める認証射程を満たさない。
  - **(2) loss-aware 一般形を採用**。`EnvironmentIdentity` は route 全体で一度だけ固定し、
    `BranchSurvives` / `BranchLost` は隣接世代の正準 `BranchImage` の存在／不在から導出する。
    caller が partial carry の定義域を選ぶ入力は設けない。失われた image は `BranchHistory` に残し、
    後の再出現を新規として数えない。共有環境型の正準インスタンスは identity を用いる。
    一般の外部 `EnvironmentIdentity` を持つ `BranchNoveltyRoute` は非認証の信頼観測境界として残す。
    catalog に登録する `CanonicalBranchNoveltyRoute` は全世代で同じ環境型 `E` を共有し
    `identify=id` を型から構成する。有限 Julia 境界でも全世代の完全環境 carrier が同一であることを
    全数検査し、caller-supplied medium embedding は受け取らない。
  - 能力喪失を含む正例として `ERIEC.RefModel.noveltyPositive_branchLost` を置き、同じ系譜で
    richer replacement と `noveltyPositive_freshSem` が成立することを Lean で証明する。
- (b) **【解決・codex 2026-08-30】「分岐」の担い手は分岐する σ-繊維とする。**
  `fiberσ(m) := {e | m ∈ σ e}` を Medium へ写した像集合を `BranchImage` とし、
  `StructuralImageIdentity` はその**像集合の等号**とする。`m` は抽出のアンカーであって
  同一性は像に置く。
  棄却理由: 対の証人 `(e₁,e₂)` は非正準で順序と組合せで水増しする。辺 `(m,e)` は
  arity を数えてしまう。`m` 単体は世代間で名前に敏感。
  **凍結文書に明記すべき帰結**: 等しい繊維像を持つ異なる `m` は**同一の分岐として数える**。
- (c) **2b（累積）は現在の型と噛み合わない**。`q : OpenSystem → Q` は履歴を表現できず、
  同じ系が別時点に再出現したことを区別できない。対象へ履歴を書き戻すのは Σ-purity 違反。
  よって累積は系譜レベルの述語として書く。これも (iii) へ収束する。

**item 3 の確定（codex 提案）**: 許す `SemanticEquivalence` は **Branch-reflecting クラス**に絞る。
すなわち `sem.rel (project frame m) (project frame k) → branchImages m = branchImages k`。
これがあれば、任意の接頭辞の後に過去に無い image を持つ `BranchFresh` から `FreshSem` への
新しい橋が直接証明できる。


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
- **陽性条件**: **【codex 2026-08-30・challenge 受理】`branchedRichLineage` は使えない。**
  `RefModel/LineageWitness.lean:169-173` は全世代 `E = Fin 2`・`σ = univ` であるため
  `BranchImage` が常に同一になり `BranchFresh` は**偽**。
  **novelty-positive な参照モデルを新規に作る必要がある。**
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


---

## 段0.5 件数表（codex 見積り 2026-08-30・naturality 最小修正を前提）

| 区分 | 件数 |
|---|---|
| (a) 新規 Lean 定義・構造 | **17**（public 13 + quotient helper 4）|
| (b) 新規 named proof | **26**。新規 DC・route の structure field proof 8〜12 を含む実作業総数 **34〜38** |
| (c) 既存 Lean 宣言の signature 変更 | **13**（Generation 7 + RefModel 6）+ 依存 proof body 5 = **18**。<br>**影響する certified public ID: VP-GEN-002〜006 の 5 件** |
| (d) Julia | 新規 finite data 3 + 新規 checker API 4 + 既存 overload 変更 1。最低 **16 test**（正 4 / 負 12）|
| (e) 台帳・manifest | 新規 VP/contract 5、既存 5 再審査。ledger 61→66、manifest / cert-scope registry **159→164** |

**段1 では `branch_transport` / `phi_rich_lax` は削除せず legacy として保持**し、冗長解消は段2 のまま。

**relation の見込み**: 有限閉接頭辞の observation / transport = `witness_validator`、
`FiniteBranchScore` = `exact_finite_decision`、`branchFresh` bridge = `lean_only`。

**負例12件の内訳（codex 列挙）**: hConv / 非単射 τ / fiber 不整合 / branch-free /
rename-only / 再出現重複 / 同一 fiber 別 m / 現 branched の偽陽性 / sem 非 reflecting / 入力境界ほか。

**自作業への波及**: 相A2 で作った `test/test_cert_scope.jl:161` は **159 を直値で持っている**。
registry とパケット記述もあわせて 164 へ追随が必要。

**凍結文書を案(2)へ修正し、段1の loss-aware 実装を開始した。**
