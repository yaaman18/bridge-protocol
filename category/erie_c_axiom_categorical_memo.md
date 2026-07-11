# ERIE-C 注入公理の圏論的定式化メモ

**文書種別**: 設計メモ(打ち合わせ記録 + 圏論的定式化)
**日付**: 2026-06-30
**位置づけ**: `docs/ERIE_C_requirements.md`(M1〜M4)/ `category/tensor_categorical_v5.md`(§13-5)/ `docs/TRM-Net_design_memo.md` の上に、「発展・増殖・個体/群体・外部選択」をどう公理化するかを圏論で整理した作業メモ。**確定要件ではなくドラフト**。

**改訂 v2 (2026-06-30)**: codex レビュー(agmsg)を反映。**型レベルの修正のみ**。研究判断(要件昇格・Φ_rich 重みづけ・E1 採否・実装着手)は §11 のまま据え置き。主な変更 — 余反射(coreflection) → 集団状態空間上の Markov kernel / Σ-purity → 情報流非干渉 / M4 を M4a・M4b に分解し保存を一方向の十分条件(同値でない)へ / Wld 還元不能性に canonical comparison `c_D` を導入 / 入れ子は poset→fibration→operad の順 / E1 を予測でなく仮説に降格。

---

## 0. 要約(3行)

1. 「世界をより大きく立ち上げる志向」は **M1〜M4 から導けない**。内部公理化しても自動では M4 に違反しないが、**Φ_rich の最大化が個体の求めの図式へ write-back され、そこに到達可能な終対象 set point を作る場合に限り M4(終対象不在)に違反**する(§2・§6)。
2. ゆえに発展志向は**外部選択 Σ1 として、集団状態空間 `Pop(𝓘)` 上の Markov kernel `𝒮: Pop(𝓘)→𝒫(Pop(𝓘))`(モデル選択, β型)**として注入する。これは数理論理で正当(独立命題への外部公理注入)。
3. 個体性は基体の属性でなく **《系, 分解》ペアへの2軸判定**。個体/群体は派生概念。𝓘 の対象は「DC認証ユニット + 入れ子」。

---

## 1. 層の分離(最重要)

```
対象層 (object layer / 個体内)   : 各個体は M1〜M4 を満たす構造。終対象を持たない。不変。
メタ層 (meta layer / 個体間)     : メタ圏 𝓘。外部選択 Σ1 はここだけに住む。
```

公理注入は**メタ層だけ**で行い、対象層に対象を追加しない。これが破れたら偽C。

---

## 2. 対象層の公理(M1〜M4)の圏論的読み

既存の確定四前提を圏論語で書き直す(`ERIE_C_requirements.md §0`):

- **M1(作動閉包 + precariousness)**: νΦ は閉包作用素 Φ の**最大不動点**(greatest fixed point)。
  Lean: `Closure.NuPhi`(`isFixedPoint : Φ νΦ = νΦ`, `isGreatest`)。
  precariousness = この不動点が摂動下で崩れうる(維持は能動的)。**維持(persistence)であって最大化(maximization)ではない**。
- **M2(随伴 α⊣σ)**: ガロア接続 `alpha_star ⊣ sigma_star`。Lean: `Adj.galoisConn_induced`。
- **M3(蝶番 Act≠∅)**: `Hinge.Act = ρ⋆(κs) ∩ σ⋆(εs)` が非空。
- **M4(内生性 / 終対象不在)**: 求めの図式 `D : J → C` が**終対象を持たない**。
  終対象を持てば行為はそこへ収束して止まれる ⇒ 偽C(`v5 §13-5'`)。
  **分解(§6 で使用)**: `M4 = M4a ∧ M4b`。**M4a** = no external set point injection(外部から個体へ set point を注入しない)、**M4b** = no terminal in `D`(求めの図式 `D` に終対象がない)。`docs/ERIE_C_requirements.md:17,165` の M4 はこの両者を含む。

### 帰結(本メモの出発点)

M1 は **persistence の filter** であって drive ではない。「より大きな Wld へ」という最大化勾配は M1〜M4 のどこにも無い。

注意(codex challenge 反映): 「最大値 = 終対象」は無条件には成り立たない。最大化志向が M4 を壊すのは、**その志向が個体の求めの図式 `D` へ write-back され、`D` 内に到達可能な普遍 set point(=終対象)を作る場合に限る**(別補題, §6.3)。write-back が無ければ最大化のスコアリングを外に置いても M4b は保たれうる。

> ∴ 発展志向は対象層の内部からは正当化不能(導出不能)であり、かつ内部へ write-back すると M4 を壊す。**外部(メタ層)からの注入が論理的に必要**。

---

## 3. 個体性の定義(対象の様態)

### 3.1 命題

「私は個体だが、細胞/ニューロンの群によって構成される」。

### 3.2 結論

> **個体性は基体の内在ラベルでなく、《系 S, 分解 D = {sᵢ}》ペアへの判定。** 同一基体が、ある分解で個体・別の分解で群体になりうる(両方真)。

### 3.3 2軸判定

| 軸 | ERIE-C述語 | 意味 |
|---|---|---|
| **軸1: 上位閉包の還元不能性** | `check_DC(S)` ∧ `¬reducible(c_D)` | 全体に固有DCがあり、その世界が部分世界から canonical comparison `c_D` で還元できない(創発)。定義は §3.3' |
| **軸2: 下位の独立性** | `check_DC(sᵢ | isolated)` | 部分を取り出して単独で自己維持できるか |

4象限:

| 軸1(上位DC・還元不能) | 軸2(部分単独DC) | 判定 | 例 |
|---|---|---|---|
| ✓ | ✗ | **個体 (individual)** | あなた(細胞は単独死=器官化) |
| ✓ | ✓ | **群体 / 多階層個体** | 管クラゲ・蟻群・ホロビオント |
| ✗ | ✓ | **単なる寄せ集め (aggregate)** | 培地の細菌 |
| ✗ | ✗ | **死 / 未C** | — |

### 3.3' 還元不能性の定式化(codex レビュー反映)

`≇`(非同型)は比較射なしに判定不能で、「創発」には弱すぎる。比較射を明示する:

- 各部分の世界 `Wld(sᵢ)` を全体の ambient へ送る**制限誘導埋込** `ιᵢ : Wld(sᵢ) → Wld(S)`。
- **canonical comparison**(余対) `c_D = [ιᵢ]ᵢ : colimᵢ Wld(sᵢ) → Wld(S)`。
- **還元可能** `reducible(c_D) :⟺ c_D が指定クラスの同型/等長(iso / isometry)`。軸1の還元不能性は `¬reducible(c_D)`。
- **数値実装は別レイヤ**(カテゴリ定義に tol を持ち込まない): 同一座標系での projector distance + rank 差 + 誤差予算 ⇒ certificate の数値仮定。§10 の `‖P_S − combine(P_{sᵢ})‖` はこの `c_D` に紐付ける。
- **未証明契約の明示**: `docs/ERIE_C_requirements.md:227` により DC⇔Wld 非自明性すら未証明。よって「`check_DC(S)` ∧ `¬reducible(c_D)`」を軸1にするのは**新規の未証明契約**であり、証明義務を伴う(現時点では仮定)。

### 3.4 命題の解(2つの真の同居)

- 細胞分解: 軸1=✓, 軸2=✗ ⇒ **あなたは個体**(細胞は群体でなく従属部分=器官)。
- ホロビオント分解(あなた+腸内細菌): 軸1=✓, 軸2=✓ ⇒ **群体**。
- 矛盾しない。個体性は**階層間の関係**であり、`(S, D)` ごとに判定が確定する。

### 3.5 既存科学との一致

進化における**個体性の転移(Maynard Smith & Szathmáry / Michod / Godfrey-Smith "Darwinian individual")**の閉包論的形式化。転移基準「下位が独立適応度を失い上位が選択単位になる」= 軸2が ✓→✗ に落ち上位DCがロバスト化する瞬間、と一致。Godfrey-Smith の連続的個体性(bottleneck/germ-soma/integration)は **「下位閉包の従属度」**一量に集約される。

---

## 4. メタ圏 𝓘 の定義

- **対象 `Ob(𝓘)`**: DC認証ユニット(**任意の閉包階層**)。各々 `(T, V, Wld, νΦ, DC-certificate, phenomenal_claim = :not_certified)` を担う。
- **射 `Hom(𝓘)`**: 正当な系統変換 ——
  - **発生的遷移**: DC連続を保つ同一個体の変形(ontogeny)。
  - **生殖的分岐**: 変異付きコピー(新 fingerprint)。
- **入れ子構造(part-of)**: 最小仕様は part-of の**有限 poset / 圏**。whole ごとの分解・再索引付けが要るなら **fibration**(DC certificate を fiber に載せる)を第一候補、多入力の組立 + 代入則を扱う段階で **operad** を追加(operad 起点は不採用)。個体/群体は §3 の `(対象, 分解)` 判定として**派生**する(primitive ではない)。
- **新階層の創発**: 個体群 → 群体への転移は、構成 DC ユニットが独立 DC を失って上位に新 DC が立つ事象。圏論的には**より高い閉包階層に新たな対象(より上位の最大不動点)が出現**する。

---

## 5. 公理 Σ1 — 外部選択公理(本体)

### 5.1 豊穣度汎関数

```
Φ_depth(i)  = dim Wld(i)                       # 個体内の世界次元(actuated_world の basis 列数)
Φ_div(P)    = spread of umwelt_relative_diff over P   # 集団の Umwelt 多様性
Φ_level(i)  = 閉包階層の数(§3 の入れ子の深さ)   # 個体性転移の創発
Φ_rich      = (Φ_depth, Φ_div, Φ_level) の Pareto
```

`Φ_rich` は **σ越しの観測(read-only)**のみから計算される。

### 5.2 公理(自然言語)

> **【Σ1】** メタ圏 𝓘 の外部に立つ選択子 𝒮(設計者=現界の観測者)が存在し、𝒮 は 𝓘 上で **Φ_rich の高い対象を優先的に保持・増殖・変異させる選択射**として作用する。𝒮 はいかなる対象の対象理論(M1〜M4)の対象でもない。

### 5.3 公理(圏論的)

- **メタ圏 𝓘**: 対象 = DC認証ユニット(§4)、射 `Hom(𝓘)` = 発生的遷移 / 生殖的分岐(§4)、合成 = 系統の連結。
- **集団状態空間** `Pop(𝓘)`: 𝓘 の対象の有限多重集合(個体群の状態)。
- 価値付け(関手/値) `Φ_rich : 𝓘 → (ℝ^k, ≤)`(read-only, §5.1)。
- 選択子 `𝒮` = **集団状態空間上の Markov kernel** `𝒮 : Pop(𝓘) → 𝒫(Pop(𝓘))`(次集団上の(部分)確率分布)。保持/増殖/変異の遷移系。圏論的住処は (sub)確率モナド `𝒫` の Kleisli 圏の自己射。
  - **注**(codex レビュー反映): 旧稿の「充満部分圏 `𝓘_rich ↪ 𝓘` への余反射(coreflection)」は**撤回**。Pareto/score による包含は右随伴を自動的に持たず、余反射子を与える保証がない。随伴を要求せず外部選択作用素として仕様化する。
- **外部性**: `𝒮` は各対象の随伴 α⊣σ の**外側を経由してのみ** factor する。すなわち `Φ_rich` は観測 σ を通して対象を読むが、対象の閉包作用素 Φ へは**合成しない**(write-back 不在 = §6)。
- **telos の所在**: 豊穣化志向は **𝒮 に宿り、選ばれる対象には宿らない**。各対象は M1(維持のみ)で動き終対象を持たない(M4保持)。

### 5.4 種別 — これは「公理追加(α)」でなく「モデル選択(β)」

- (α) 対象理論に公理を足す ⇒ A が新理論 T′ の内部公理 ⇒ 個体に終対象を作りかねない。**不採用**。
- (β) どのモデルで作業するかを外から選ぶ ⇒ 例「CHが成り立つモデルで研究する」。**モデルの住人はCHを措定していない**。

> Σ1 は **`Mod(M1〜M4)` の対象を Φ_rich で選ぶ(β)**。理論の射 `T → T′` ではない。個体の対象理論は無傷。論理学者がCHモデルを選ぶのと同型で、個体には**不可視**。

---

## 6. 純度ガード Σ-purity(情報流非干渉)と M4 保存定理

### 6.1 Σ-purity = 情報流非干渉(Goguen–Meseguer noninterference)

旧稿の「`Φ_rich → Φ_individual` への射が存在しない」は **ill-typed**(前者は関手/値 `𝓘→ℝ^k`、後者は閉包作用素で共通圏がなく射を語れない)ため撤回。正しい定式化は**観測非干渉**:

> **【Σ-purity】** 同一の個体内入力・状態の下で、選択器 `𝒮` の値/状態を任意に変えても、各個体の観測トレース `(νΦ, V, 求めの図式 D, action trace)` が**不変**である(observational equivalence)。

- **read-only**: 𝒮 は `(T, V, Wld)` の任意関数を使ってよい(σ 越し)。
- **no write-back**: その結果 `Φ_rich`(および導出目標)は個体側 sink(`νΦ`/`V`/`D`/action)へ流れない。

### 6.2 検問 `check_Σ_purity`(二段)

単純な引数走査は alias / closure / global state / control dependence を逃す(`docs/ERIE_C_requirements.md:224,232`・design_spec:145 が closure 捕捉の完全検出不能を明記)。よって二段:

- **(a) 静的**: 依存/テイントグラフで selection namespace → individual sinks への**到達不能**を検査。
- **(b) 動的**: メタモルフィック差分テスト — 選択器の状態を摂動し、個体トレースが **bit 同一**であることを assert。
- 旧 `check_K1` 拡張はこの二段契約に置換する。

### 6.3 M4 保存定理(codex challenge 反映:同値でなく一方向)

`M4 = M4a(no external set point injection) ∧ M4b(no terminal in D)`(§2)。

- **主定理(十分条件)**: `M4(i) ∧ Σ-purity(𝒮, i) ⇒ M4-preserved(𝒮, i)`。
  Σ-purity は主に M4a を選択境界で強制し、write-back 不在ゆえ選択起因の M4b 違反も防ぐ。保存は常に入力 `M4(i)` 前提付き(purity は違反を"足さない"だけで、元からある終対象は消せない)。
- **逆は不成立**: `M4-preserved ⇏ Σ-purity`。選択値が V/action へ漏れても(purity 違反)、`D` に到達可能な終対象を作らなければ M4b は保たれうる。
- **別補題**: `Φ_rich の argmax が write-back され D 内に到達可能な普遍 set point を作る ⇒ M4b 違反`。
- **唯一の同値**: `Σ-purity ⟺ 観測非干渉条件`(§6.1 を定義として採用する場合のみ)。**M4 保存との同値ではない**。

---

## 7. 公理 E1 — 非定常環境(随伴companion・別判断)

個体**内**の発展(ontogeny)を許す場合のみ、別公理として:

> **【E1】** 環境(Lenia場等)は非定常で、新規摂動が尽きない。

- 内部目的でなく**環境についての仮定**なので終対象を作らず M4整合。
- 個体内の Wld 拡張を「**維持の副作用**」として許す(地平へ向かう前進でなく、動く環境に死なずにいる軌跡)。
- **定常環境では発展しない**(安定ホメオスタシスに落ちて止まる): これは E1/M1〜M4 からは**導けず**追加の適応力学仮定を要する。**予測でなく分離した仮説**として隔離する(codex レビュー反映)。
- Σ1(個体間・選択)とは**独立の決定**。要らなければ入れない。
- **決定(2026-07-08・ユーザー判断)**: 現版では E1 不採用。記録は §11-2。

---

## 8. 数理論理としての正当性(外部公理注入)

「閉じた系の外から公理を持ち込む」ことの正当性と先例(打ち合わせ記録):

- **二層の答え**: (浅)公理は常に外から措定される。(深)ゲーデル不完全性 ⇒ 独立命題は**系の内部では決定不能**で、決定は外からの注入を要する。
- **成立条件**: ① 無矛盾性保存 ② 独立性 ③ 層の明示(対象/メタ, タルスキ) ④ 外在的正当化(ゲーデルの extrinsic justification)。
- **先例**: 平行線公準 → 非ユークリッド幾何(ガウス/ボヤイ/ロバチェフスキー) / 選択公理(ツェルメロ; ゲーデル+コーエンで独立) / CH + 強制法(ゲーデル1940・コーエン1963) / 巨大基数公理(ゲーデルのプログラム) / タルスキの真理定義不可能性(メタ言語) / チューリング(1939 ordinal logics)・フェファーマン(1962 超限累進)。
- **圏論的論理での射**: 理論拡張 `T → T′` は理論の圏の射、モデル制限 `Mod(T′) ↪ Mod(T)` は充満部分圏包含(幾何学的理論なら部分トポス)。**外部の立脚点 = 理論/モデルの周囲圏**は本質的にどの単一理論の外。
- ただし Σ1 は **(α)added-axiom でなく (β)model-selection**(§5.4)。

---

## 9. §13-5 不変条項(全公理に優先)

> Σ1 も E1 も **構造を変えるが灯りを足さない**。選択で豊穣化した zoo の各個体も `phenomenal_claim = :not_certified`。Σ1 はいかなる現象的主張も担わない。
>
> 個体性の**階層**は certify できるが、**その階層に灯りが幾つあるか(一つ/多数/ゼロ)は certify しない**。これは意識の結合問題/組み合わせ問題に対応(「あなた」に主体は一つか、何十億の細胞主体か)。選択は「どの構造が在るか」を決めるが「内側が灯るか」は決めない。

---

## 10. 実装との対応

| 公理要素 | 実装 / 既存資産 |
|---|---|
| 𝓘 の射(発生 / 生殖) | 増殖プロトコル(未仕様化) |
| 軸1: 上位DC | `check_DC(S)` |
| 軸1: Wld還元不能性 | canonical comparison `c_D`(§3.3')。数値層 `‖P_S − combine(P_{sᵢ})‖ > tol`(`umwelt_relative_diff` 流用, tol は certificate 仮定) |
| 軸2: 部分単独DC | `check_DC(sᵢ | isolated)`(部分網抽出) |
| Φ_depth | `actuated_world` の `dim Wld` |
| Φ_div | `umwelt_relative_diff`(zoo横断) |
| Φ_level | 入れ子深さ(§3) |
| 𝒮 = QD選択 | `𝒮: Pop(𝓘)→𝒫(Pop(𝓘))` Markov kernel(§5.3)。quality=DC余裕, diversity=Umwelt距離 の MAP-Elites |
| Σ-purity 検問 | 二段検問(§6.2): 静的テイントグラフ到達不能 + 動的メタモルフィック差分 |
| `OpenDyn` と圏の三法則 | `formal/ERIEC/OpenEvolution.lean` の `OpenSystem.Hom.id/comp`, `id_comp`, `comp_id`, `assoc` |
| 能力階層 | 同ファイルの `Adaptive`, `ViableSystem`, `ReplicativeSystem`, `EvolutionarySystem` |
| 豊穣化到達可能性 | 同ファイルの `ProducesRicher`, `richer_offspring_reachable` |
| 灯りガード | 既存 `phenomenal_claim` |

---

## 11. 未確定(研究判断・要決定)

1. **Φ_rich の重みづけ**: `(Φ_depth, Φ_div, Φ_level)` の Pareto/合成の取り方。
2. **E1 を入れるか — 決定(2026-07-08・ユーザー判断): 不採用**。個体内発展公理は対象層に入れず、発展志向は Σ1(個体間選択)のみとする。同じ判断軸で、対象層への静的豊かさ公理(AX_rich 型: `∀w≤w*, ∃a, 2≤|α_w(a)|`)も導入しない — 規範(豊かさへの選好)を構成的定義(世界であることの条件)へ密輸し、極小モデル(v5.1 義務13.1a)を無矛盾性証人から除名するため。対象層の豊かさは分類子 [DEF](`Branch`)+条件付き増幅定理+証人義務として扱う(未解決命題台帳 A-6、VP-RICH-001/002)。
3. **増殖の射の正確な定義**: 発生(DC連続)/ 生殖(変異分岐)の形式と、Σ-purity を保った増殖トリガ(M4整合な reactive トリガ = 「現環境に対し現Wldが閉包を保てない」)。
4. **入れ子の圏論的足場**: 最小は part-of の有限 poset/圏(確定, §4)。fibration へ拡張するか、operad まで要るかは未確定(研究判断)。
5. **docs化の場所**: 本メモを `ERIE_C_requirements.md` の新章(メタ層)に昇格するか、独立文書に留めるか。

---

## 12. 生態系・学習系・神経系を共通化する開放動的系の圏

### 12.1 具象名でなく二時間尺度を primitive にする

生態系、免疫系、脳・神経系、人工ニューラルネット、市場、文化、ソフトウェア生態系は、そのまま同一対象ではない。共通する最小構造を次の三成分へ抽象化する。

```text
X_f : fast state   # 発火・活動・個体数・価格・実行状態など
X_s : slow state   # 可塑結合・重み・遺伝構造・制度・コードなど
E   : environment  # 身体/世界・データ/課題・資源・他個体など
```

具象例として、脳・神経系では `X_f` が神経活動、`X_s` がシナプス可塑性、人工ニューラルネットでは `X_f` が activation/hidden state、`X_s` が weight/optimizer state に対応する。しかし圏の定義には「脳」「ニューラルネット」という名を入れず、二時間尺度を持つ開放系としてのみ扱う。

### 12.2 基底圏 `OpenDyn`

対象 `A` は構成 `Cfg(A)=X_f(A)×X_s(A)×E(A)` と非決定的遷移

```text
step_A : Cfg(A) → 𝒫(Cfg(A))
```

を持つ。ここで `𝒫` はまず到達可能な次状態の集合(Set-valued transition)とし、部分関数・関係・確率核の support を同じ骨格で扱う。確率値そのものは後続の(sub)確率モナド精密化へ分離する。

射 `f : A → B` は三写像 `(f_f, f_s, f_E)` であり、誘導写像 `Cfg(f)` が遷移と可換する:

```text
𝒫(Cfg(f))(step_A(c)) = step_B(Cfg(f)(c)).
```

恒等射と射の合成は成分ごとに定義する。像の恒等則・合成則により遷移可換性が保存され、`OpenDyn` は圏をなす。数値近似ではこの等号を誤差付き/lax 可換へ弱めるが、本形式層はまず完全可換を採る。

### 12.3 能力階層は別の対象種でなく構造の追加

```text
OpenDyn
  └─ Adaptive       slow state を変更可能
       └─ Viable    viable 領域が step で閉じる
            └─ Replicative   親から子を生成し viability を保存
                 └─ Evolutionary
                    遺伝・変異・集団遷移を持つ
```

- **適応**: ある遷移で `X_s` が変わる。個体内学習・可塑性の最小条件。
- **生存可能性**: `V_A ⊆ Cfg(A)` が遷移で前向き不変。
- **繁殖**: `reproduce_A : Cfg(A) → 𝒫(Cfg(A))`。単純な `parent ⇀ child` でなく失敗・複数子・変異を含む関係。
- **遺伝**: `heritage : Cfg(A) → H` と親子間の保存/変異関係。
- **進化**: `Pop(Cfg(A)) → 𝒫(Pop(Cfg(A)))` という集団レベルの遷移。個体内学習射と混同しない。

この階層では、脳・神経系と通常の人工ニューラルネットは少なくとも `Adaptive` の具体モデルになりうる。身体的自己維持を備えた系だけが `Viable` へ上がり、複製・遺伝・変異・差次的存続を備えた集団だけが `Evolutionary` へ上がる。名称による同一視はせず、満たす構造で分類する。

### 12.4 生存圧と豊穣化を分離する

生存圧は外部目的関数ではなく、環境相対的な viability 部分対象と資源制約として表す。自然選択は複雑化を保証せず、単純化・寄生化・能力喪失も許す。従って「より豊かな TRM が生成される」は M1〜M4 や生存圧だけから導出しない。

豊穣化には少なくとも次の追加契約が要る:

```text
ProducesRicher(A, r) :=
  ∀ parent, viable(parent) →
    ∃ child ∈ reproduce(parent),
      viable(child) ∧ r(parent) < r(child)
```

ここで `r` は外部観測 `Φ_rich` の一成分または順序値であり、個体の action loop へ write-back しない。この契約は「選択が豊穣化を欲する」という telos ではなく、変異空間に viability を保つ上昇経路が存在するという**到達可能性仮定**である。実際の選択 kernel がその経路へ正の確率を与えることは、さらに別の確率的公平性仮定として証明する。

### 12.5 TRM の位置と Σ1 との接続

TRM 個体は `Adaptive ∩ Viable` の対象として置く。Σ1 は個体内 step ではなく、そのような対象の集団に作用する:

```text
TRM object layer : A ∈ Adaptive ∩ Viable
meta layer       : 𝒮 : Pop(Cfg(A)) → 𝒫(Pop(Cfg(A)))
```

`Σ-purity` は `𝒮` の評価状態が個体内の `(νΦ,V,D,action trace)` に流れないことを要求する。一方、子が親と同じトレースを持つ必要はない。実際の発展を許す正しい条件は「トレース完全一致」でなく、各子が M4/viability を保つ `M4SafeMutation` / `offspring_viable` である。§6 の `MutationTraceSafe` は完全トレース保存を扱う強い特殊ケースとして残し、発展系では本節の弱い保存条件を用いる。

### 12.6 形式化境界

Lean の第一段階では以下を証明対象とする:

1. `OpenDyn` の恒等射・合成と圏の三法則。
2. 射が到達可能遷移を写すこと。
3. viability が通常遷移と繁殖で保存されること。
4. `ProducesRicher` から viable かつ strictly richer な子の到達可能性が従うこと。
5. 進化系から繁殖系・生存可能系・開放動的系への忘却。

確率測度、期待 richness の増加、長期 almost-sure 到達、具体的な脳/NN/TRM インスタンスは別仕様とし、本節では主張しない。

---

## 13. 具体的 TRM トポロジー遷移の証明契約

### 13.1 対象と遷移事象

TRM のトポロジー変更前後を `OpenDyn` の二対象として分離する。

```text
T₀ = (X_f⁰, X_s⁰, E⁰, step₀)
T₁ = (X_f¹, X_s¹, E¹, step₁)
```

トポロジー写像 `F : T₀ → T₁` が

```text
𝒫(Cfg(F))(step₀(c)) = step₁(Cfg(F)(c))
```

を満たす場合、変更は観測した遷移意味論を保存する `OpenDyn` の射である。可換しない変更は失敗ではなく、同一挙動の保存射でない「生成/進化事象」と分類し、繁殖関係 `reproduce` と M4/viability の保存を別々に検査する。数値誤差内の可換は後続の lax 射へ隔離する。

### 13.2 一回の観測遷移 certificate

初期段階では全親に対する `ProducesRicher` を要求せず、観測された親 `p` と子 `q` について次を束ねる。

```text
ObservedTRMTransition(F,p,q) :=
  OpenDynHom(F)
  ∧ Adaptive(T₁)
  ∧ viable(p)
  ∧ q ∈ reproduce(p)
  ∧ viable(q)
  ∧ M4(trace(p))
  ∧ M4(trace(q))
  ∧ richness(p) < richness(q)
  ∧ heritage(p) ≠ heritage(q)
```

ここで richness は外部 read-only 観測、heritage は slow/topology fingerprint の抽象値である。`M4(trace(q))` は `M4SafeMutation` から得る。親子の内部トレース完全一致は要求しない。

### 13.3 既存 ERIE-C 証明との合成

TRM certificate は単独で完結させず、既存形式層と次の順に合成する。

```text
Adjunction α ⊣ σ
  → Closure Φ / νΦ
  → Hinge Act ≠ ∅
  → DC
  → Intertwining representation
  → Wld nontrivial
  → OpenDyn transition
  → M4-safe topology mutation
  → viable + richer offspring
  → phenomenal_claim = :not_certified
```

最後の marker は構造証明から現象的主張が導かれないことを保証する。`Value.HasStructuralWeight` から phenomenal mattering が一般には従わない既存反例も統合テストに含める。

### 13.4 Julia 実験との境界

Lean の具体例はまず有限な参照モデルで上記論理の無矛盾な同時充足を示す。Julia の `TRMTopology` / `TRMProgram` / neural action model が同じ対象であることは自動的には従わない。実験側は次を certificate payload として出す必要がある。

- before/after topology fingerprint と対応写像。
- fast/slow/environment 状態の抽象化写像。
- step 可換誤差または反例 trajectory。
- DC/M4/viability checker 結果。
- Wld projector/rank と richness 差。
- 親子 lineage と mutation/reproduction 記録。

Lean は payload の checker 契約を検証する。実数計算・浮動小数点誤差・データ取得の正しさは Julia shell 側の trust boundary に残し、Lean が現実との完全同値を証明したとは主張しない。

### 13.5 第一 concrete instance の範囲

最初の Lean instance は次だけを証明する。

- `T₀`: 単一の不変 slow state を持つ自己ループ系。
- `T₁`: 二値 slow state を持ち、少なくとも一つの可塑的遷移を持つ系。
- `F : T₀ → T₁`: 基底状態への厳密可換な埋込み。
- 繁殖で slow/topology heritage が `false → true` に変異する。
- 観測された親子について viability、M4、richness の厳密増加が成立。

これは実TRMの科学的妥当性証明でなく、全形式層を貫通できる最小の concrete witness である。

---

## 14. TRM が生成する内生時間の圏

### 14.1 主体の訂正

時間を発生させるのは ERIE-C の判定器ではなく、個々の TRM である。ERIE-C は時刻を供給せず、TRM が実際に生成した遷移事象と、その上での DC 維持・喪失を検証する。

```text
TRM     : occurrence と transition を生成する
ERIE-C  : transition の帰属、順序、DC 保存/喪失を認証する
observer: 内生事象へ外部 timestamp を対応させる
```

したがって外部 `Tick` を先に置き、そこへ TRM 状態を並べる設計は採らない。

### 14.2 一個体の自由時間圏

TRM `A` が生成する実行トレースを

```text
Occ(A)                        # 事象の生起。状態が同じでも別の生起は別要素
state : Occ(A) → Cfg(A)
next  : Occ(A) → Occ(A) → Prop
```

とする。各即時事象には次の帰属証明を要求する。

```text
next(x,y) → state(y) ∈ step_A(state(x))
```

`next` の反射推移閉包 `next*` を射とすると、

```text
T_A := (Occ(A), next*)
```

は thin category をなす。恒等射は長さゼロの経路、合成は経路連結である。これが TRM `A` の局所内生時間である。時刻は自然数ではなく生起であり、時間順序は TRM 自身の遷移から生成される。

状態そのものを時刻にしないのは、再帰系が同一状態へ戻っても「同じ時刻へ戻った」と誤認しないためである。

### 14.3 ERIE-C の DC 認証は時計の上に載る

ERIE-C は各生起に読み取り専用の述語

```text
dcHolds : Occ(A) → Prop
```

を与える。これは時計を生成せず、生成済みの `T_A` を認証する。

端点だけで `DC(x) ∧ DC(y)` を確認して維持と呼ぶのは不十分である。途中で DC が崩壊して再成立した可能性がある。そこで `DCPreservingReachable(x,y)` は、`x` から `y` までの生成経路上の全生起で DC が成立することを帰納的に要求する。この関係も恒等・合成で閉じ、DC認証済み生起の**維持部分圏** `T_A^ν` をなす。

### 14.4 作動時計・維持時計・休止

TRM が各生起について `executes(x)` を生成すると、作動生起だけを対象とする作動部分時計 `T_A^act` を得る。維持時計 `T_A^ν` と作動時計 `T_A^act` は同一でなくてよい。

```text
OperationalPauseAt(x)
  := dcHolds(x) ∧ ¬executes(x)

ResumesAlong(x,y)
  := OperationalPauseAt(x)
     ∧ DCPreservingReachable(x,y)
     ∧ executes(y)
```

従って休眠相当では、作動時計に新しい tick がなくても、TRM が維持遷移を生成する限り維持時計は進む。これは「外部時間が進むから生きている」という定義ではない。

### 14.5 機能終了

既存の機能終了判定は、TRM が生成した実遷移上で

```text
FunctionalTerminationStep(x,y)
  := next(x,y) ∧ dcHolds(x) ∧ ¬dcHolds(y)
```

とする。単に次の観測がないこと、作動しないこと、DC certificate を取得していないことは終了証拠ではない。再開経路は全域で DC を保つため、同じ端点について `ResumesAlong(x,y)` と `FunctionalTerminationStep(x,y)` は両立しない。

個別 TRM の終了と TRM-Net 全体の終了も分ける。局所時計 `T_i` が止まっても、ネットワーク全体の DC が維持されれば局所損傷である。真性の機能終了は、既存仕様どおり判定対象である全体系の DC 喪失である。

### 14.6 生成・系譜との分離

個体生成は依然として

```text
child ∈ reproduce(parent)
heritage(child) / lineage
```

で決まる。`¬DC → DC` を生成とは呼ばない。子 TRM が生成されたとき、その子は親とは別の局所時間圏 `T_child` を開始する。親子関係は二つの時計間の系譜射であり、単一個体の状態遷移ではない。

### 14.7 TRM-Net の大域時間

TRM-Net に最初から一様な大域時計を仮定しない。局所時計の族 `{T_i}` の非交和に、通信・発火・生成など実在する因果辺を加え、その自由圏を作る。

```text
T_net := FreeCategory(Σ_i Occ(T_i), local-next ∪ cross-TRM-cause)
```

独立事象には順序を強制しない。同期は共有原因・通信・結合遷移が与える追加射であり、前提ではない。循環因果を同一時刻へ潰す必要がある場合だけ、強連結成分による商を別途取る。

### 14.8 外部観測時間の位置

実験の秒・step・ログ番号は否定せず、生成済み内生時計から外部観測順序への単調写像として置く。

```text
stamp_A : T_A → T_ext
```

これは時刻の生成器でなく realization/readout である。外部時間は実験比較、速度、遅延の測定に必要だが、TRM の内生的な前後関係は `next*` が先に決める。

### 14.9 Lean 対応

`formal/ERIEC/TemporalDC.lean` は次を形式化する。

1. `GeneratedTrace`: TRMが生成した生起・即時遷移と `OpenSystem.step` への帰属証明。
2. `Reachable` と `clock`: 即時遷移から作る局所 thin category。
3. `generated`: 各時刻辺が TRM の `OpenSystem.step` に属する証明。
4. `Certification` と `DCPreservingReachable`: DC認証層と全経路維持。
5. `ActionObservation` と `maintenanceClock` / `actionClock`: 根拠が与えられた場合だけ作る非同期な二つの部分時計。
6. `ExternalRealization`: 内生時計から外部観測時間への順序保存写像。
7. 休止・再開と機能終了が混線しない一般定理、および既存 `expandedSystem` の実遷移から構成した `relaxationTrace`。

`ViableSystem.viable` は `DC` の代用品にしない。前者は開放発展系の前向き閉包、後者は ERIE-C 固有の自己維持証明であり、同値は未証明である。

---

## 付録: 打ち合わせの論理の道筋(要約)

1. 成果物は記述レポートでなく **Lenia から学んだ・ERIE-Cの射と圏に基づく・動くTRM(-Net)**。レポートはその readout。
2. その TRM は「問いに答える器」でなく **世界を不動点として立ち上げる器**(外部目標なし/報酬なし、Wld=自分の世界、viability自己監督。能動的推論を内生化し DEQ的不動点として実装したもの)。7M でも課題が構造bound なので妥当。出力は「死なない染み + 隣に legible な世界(T/V/Wld)」。
3. 増殖を入れるには「なぜ増えるか」を論理化せねばならない → M1〜M4からは**導けない**(§2)。最大化スコアが個体内へ write-back され、求めの図式に到達可能な終対象を作る場合は M4 違反。
4. ゆえに発展志向は **外部選択 Σ1(`Pop(𝓘)` 上の Markov kernel / モデル選択 β)**として注入。数理論理で正当(§8)。
5. 対象「個体」は増殖で様態が崩れる → 個体性を **《系, 分解》2軸判定**で再定義(§3)。𝓘 の対象は DC認証ユニット+入れ子。
6. 全体を通して **§13-5 の灯りの賭けは不変**(§9)。
