# ERIEC 検証点台帳設計仕様 v2

対象: 圏論仕様 → Lean 証明 → Julia 実装 → certificate の追跡台帳  
目的: 「宣言名が存在する」ことと「文書の主張が証明された」ことを分離し、後者だけを完全証明として扱う。

本書は台帳と証明工程の設計仕様である。現行 `specs/ledger.toml` の内容は本書の批准・移行が完了するまで変更しない。

---

## 1. 問題定義

現行 schema v1 の G1 は、主として次を検査する。

1. `lean_decl` と同名の宣言が `lean_file` に存在する。
2. `lake build` が成功する。

これは型検査として必要だが、文書の `claim_ja` と Lean 宣言の命題が同じ強さであることを保証しない。たとえば次はすべてG1を通過できる。

- 文書が `A → B` を要求しているのに、Lean が `B → B` を証明する。
- 文書が `A ∧ B ∧ C` を要求しているのに、Lean が `A` だけを証明する。
- 文書が前提から崩壊を導出するのに、Lean が崩壊そのものを前提に取る。
- 文書が反模型の構成を要求しているのに、Lean が結論側の一要素だけを否定する。
- `[CNJ]` を数値例で観測し、定理を認証したように扱う。

schema v2 は、この種の弱化を台帳段階で禁止する。

---

## 2. 基本原則

### 2.1 一検証点一判断

一つのVPは、一つの論理判断だけを表す。

- 一つの定義
- 一つの定理
- 一つの反例または反模型
- 一つの構成義務
- 一つの公理・フィールド
- 一つの予想

複数の判断をまとめる必要がある場合は、証明対象でない `claim_group` を作り、原子VPを `children` に列挙する。グループ自身へ `certified` を直接付与してはならない。全子VPが所定状態に達したときだけ `coverage = "complete"` とする。

### 2.2 文書タグを保存する

`claim_kind` は次のいずれかとし、別種へ昇格させない。

| claim_kind | Lean上の表現 | 完了条件 |
|---|---|---|
| `definition` | `def` / `structure` / `abbrev` | 指定型で定義される |
| `theorem` | `theorem` | 指定命題の証明が通る |
| `field` | structure のフィールド | 仮定として明示される |
| `obligation` | 具体的 witness を返す theorem/def | witness と全充足証明がある |
| `counterexample` | `∃ model, assumptions model ∧ ¬ target model` | 同一模型内で前提と反例を構成する |
| `conjecture` | `def name : Prop` | 未証明であることを維持する |
| `refuted` | 反例 theorem | 反証済みとして墓標化する |

`field` を theorem に、`conjecture` を観測結果だけで theorem に変えてはならない。

### 2.3 Leanシグネチャを先に凍結する

実装前に、binder・仮定・量化順・含意方向を含む完全なLean型を `statement_spec` として凍結する。

例:

```lean
theorem K_absorbing
    (hReach : Reachable step t v)
    (hst : step s t)
    (hv : v ∈ V) :
    s ∈ downTo step V
```

宣言名だけを予約して実装者に命題本文を推測させてはならない。

### 2.4 仮定の強化を検出する

各VPは `assumptions` と `conclusion` を別フィールドで保持する。Lean型から抽出した仮定集合が凍結仕様より強い場合、G1を失敗させる。

特に以下を禁止する。

- 証明すべき結論を仮定に追加する。
- 文書にない全域性、有限性、非空性、選択関数を追加する。
- `↔` を `→` に弱める、または指定方向を反転する。
- 反例の前提側と結論側を別々の模型で示す。

### 2.5 証明と実装を直交させる

すべてのLean定理にJulia APIが必要なわけではない。`realization_kind` を次から選ぶ。

- `formal_only`: Lean証明のみ。
- `executable`: 有限モデル上の決定手続きがある。
- `numerical`: 許容誤差を伴う数値近似。
- `witness`: 具体的反模型・参照模型を構成する。
- `none`: field、conjectureなど実行対象でない。

これにより、無関係なLean定理とJulia関数を「存在する」という理由だけで接続することを防ぐ。

---

## 3. schema v2

### 3.1 原子VP

```toml
schema_version = 2

[[claim]]
id                 = "VP-DYN-COLLAPSE-CONF-001"
group_id           = "GRP-DYN-5-4"
source             = "category/三層構造の圏論的定式化_v5_1.md#定理-5-4-1"
source_label       = "定理 5.4(1)"
claim_kind         = "theorem"
statement_ja       = "任意の初期構成は高々 |W|+|C| 歩で恒久的にκ=∅となる"
direction          = "implies"

assumptions = [
  "Finite C",
  "FiniteLinearOrder W",
  "Sig2 family threshold",
  "R2Prime drift",
]
conclusion = "∃ n ≤ card W + card C, ∀ k ≥ n, kappa (iterate upd k c0) = ∅"

lean_decl          = "ERIEC.Dynamics.collapse_conf"
lean_file          = "formal/ERIEC/Dynamics.lean"
statement_spec     = "specs/statements/VP-DYN-COLLAPSE-CONF-001.lean"
statement_hash     = "sha256:<normalized-Lean-type>"
allowed_axioms     = ["propext", "Quot.sound", "Classical.choice"]

realization_kind   = "executable"
julia_api          = "check_finite_collapse"
julia_file         = "src/dynamics.jl"
test_files         = ["test/test_dynamics.jl"]
contract_id        = "dynamics.collapse.conf"

depends_on         = ["VP-GRA-SIG2-001", "VP-DYN-R2P-001"]
owner              = "codex"
pinned             = false

spec_status        = "frozen"
proof_status       = "unproved"
implementation_status = "untested"
certification_status  = "uncertified"
```

### 3.2 claim group

```toml
[[claim_group]]
id       = "GRP-DYN-5-4"
source   = "category/三層構造の圏論的定式化_v5_1.md#定理-5-4"
title_ja = "普遍内的地平・蝶番崩壊"
children = [
  "VP-DYN-COLLAPSE-CONF-001",
  "VP-DYN-PATH-ITERATE-001",
  "VP-DYN-TOTAL-ORBIT-001",
  "VP-DYN-HINGE-EMPTY-001",
  "VP-DYN-LEAVE-V-001",
]
coverage = "partial"
```

### 3.3 状態を一本化しない

線形な単一 `status` は廃止し、次を独立に記録する。

| 軸 | 値 |
|---|---|
| `spec_status` | `draft / reviewed / frozen / changed` |
| `proof_status` | `not_applicable / unproved / proved / refuted / failed` |
| `implementation_status` | `not_applicable / unimplemented / implemented / tested / failed` |
| `certification_status` | `uncertified / contract_certified / fully_certified / invalidated` |

`fully_certified` の必要条件は claim kind ごとに異なる。たとえば `formal_only` theorem はJulia実装なしで完全認証できる。一方 `executable` theorem はLean証明、checker、対応の健全性説明、対象テストが必要である。

### 3.4 証拠

各状態変更は次を持つ。

```toml
[[claim.evidence]]
gate       = "G1"
result     = "pass"
log        = "logs/gates/VP-DYN-COLLAPSE-CONF-001/G1-<timestamp>.log"
source_rev = "<git-tree-or-content-hash>"
artifact_hash = "sha256:<olean-or-test-artifact>"
```

ログを上書きしてはならない。ソース変更後は以前の証拠を保持したまま `certification_status = "invalidated"` とする。

---

## 4. ゲート設計

### G0: 文書被覆・命題凍結

実装前の必須ゲート。

1. `[DEF] [THM] [FLD] [OBL] [CNJ]` を文書から抽出する。
2. 各判断に原子VPが一つ対応することを検査する。
3. binder、量化順、仮定、結論、`→/↔/¬/∃` をレビューする。
4. 完全Lean型を `statement_spec` に保存する。
5. 正規化した型の `statement_hash` を固定する。
6. 典拠に `‡` がある場合は `reconstructed = true` と批准状態を記録する。

G0未通過のVPへLean実装を開始してはならない。

### G1: 厳密な形式証明

次をすべて要求する。

1. `lake build` が成功する。
2. 完全修飾宣言が存在する。
3. `#check lean_decl` の型が `statement_spec` と定義的に一致する。
4. 正規化した実際の型ハッシュが `statement_hash` と一致する。
5. `#print axioms lean_decl` が `allowed_axioms` の部分集合である。
6. `sorryAx`、新規 `axiom`、仕様外のtypeclass仮定がない。
7. 依存VPが要求状態にある。

名前とコンパイルだけではG1を通過させない。

### G2: Lean–Julia意味契約

`realization_kind` が `formal_only/none` ならG2は `not_applicable` とする。それ以外は次を要求する。

1. Julia symbolがexportされている。
2. checkerの入力がLean側の有限符号化と対応する。
3. checkerが何を判定するかを `checker_semantics` に記載する。
4. theoremとの関係を `decides / sound_approximation / witness_only / observation_only` から選ぶ。
5. `observation_only` は theorem の証明証拠にならない。

### G3: 実装試験

最低限、次の三種類を要求する。

- 真証人または正常系。
- 偽証人または反例系。
- 境界条件。空集合、零次元、最大階数、閾値一致など。

数値層では `tol/seed/repeats/threshold` をcertificate仮定として固定する。有限checkerでは、可能なら全列挙テストまたはLean側のsoundness theoremを付ける。

### G4: artifact認証

certificate catalog は次を保存する。

- contract ID
- 完全修飾Lean宣言
- `statement_hash`
- Julia checkerと意味関係
- テストログのhash
- 依存contract

依存グラフは `payload → contract → exact Lean statement` まで到達しなければならない。

### G5: 文書被覆閉包

節または定理グループについて、全原子VPを走査する。

- すべて完全認証: `coverage = "complete"`
- 一部のみ: `coverage = "partial"`
- VPなし: `coverage = "missing"`
- 予想または批准待ちを含む: `coverage = "open"`

「文書全体が証明済み」という表現は、対象範囲のG5が `complete` の場合だけ許可する。

---

## 5. 反例・構成義務の規律

### 5.1 反例

反例VPは必ず次の形にする。

```lean
theorem counterexample :
  ∃ model, Assumptions model ∧ ¬ Target model
```

`¬ Target zeroOperator` だけでは、前提を満たす模型との組が示されないため反例VPを閉じない。双方向同値の反証は、前向反例と逆向反例を別VPにする。

### 5.2 構成義務

参照模型は、単なる状態遷移表ではなく、要求される全構造と充足証明を一つのwitness packageに含める。

```lean
structure ReferenceWitness where
  model : Model
  stable : AXStable model
  dynamics : RequiredDynamics model
  target : RequiredProperty model
```

義務13.1a、13.1b、13.2は別VPにする。`‡` 依存の13.1bを無印の13.1aへ混ぜない。

---

## 6. 現行VPの分割方針

少なくとも以下は分割が必要である。

| 現行VP | 必要な原子VP |
|---|---|
| `VP-CLP-001` | 同時更新定義、κ降下、蝶番空性、K吸収、臨界減速予想。臨界減速は `conjecture` |
| `VP-DYN-001` | `Conf`、`upd`、R2′ field、構成崩壊、経路反復、全域軌道、K吸収、境界一方向、INS特徴づけ、Transport定義 |
| `VP-WLD-002` | `Wld_band`、L不変性、零帯域=Fix、帯域単調、`Wld⊆Eη`、`lambdaMax`、`chi`、非自明性条件 |
| `VP-VAL-002` | `normalized_V`、非空時well-defined、範囲、内生性、`weighted_O`、外部述語反模型 |
| `VP-WDC-002` | 前向反例、逆向反例。別模型・別VP |
| `VP-INV-001` | 静的保存、配置更新保存、漂移等変field、全更新可換、ユニタリ共役、INS保存、E5 field |
| `VP-REF-001` | 13.1a安定模型、13.1b動的拡張、13.2非退化模型 |

現行 `certified` は削除せず、`legacy_certification = "contract-certified-v1"` として保存する。分割後の子VPが揃うまではグループ被覆を `partial` とする。

---

## 7. 証明手順

### 段階0: 現行証拠の保全

1. 現行29 VPとG1–G4ログを読み取り専用のlegacy evidenceとして保持する。
2. 現行宣言を削除・改名しない。
3. schema v2の子VPを追加し、既存宣言を再利用できる場合だけ紐付ける。

### 段階1: 文書の原子化

1. v5.1 §1–20からタグ付き判断を抽出する。
2. 定義、field、theorem、obligation、conjecture、counterexampleへ分類する。
3. 一つの番号に複数項がある場合は枝番VPを作る。
4. 各VPの完全Lean型を人間可読形とLeanファイルの双方で凍結する。
5. `claim_group` 被覆表を生成する。

### 段階2: 既存Lean宣言の強度監査

各宣言について次を比較する。

1. 文書の全称・存在量化。
2. 前提集合。
3. 結論。
4. 含意方向。
5. 同一模型・同一状態・同一階数を要求しているか。
6. 仕様外の有限性・決定可能性・選択を追加していないか。

完全一致なら子VPへ再利用する。弱い宣言は補題として残し、新しい仕様名の定理を追加する。

### 段階3: 依存順の証明

推奨順は次の通り。

1. **基礎定義とfield**: `Conf/upd/R2′`、`Wld_band/Eη/chi`、正規化価値。
2. **局所補題**: κ降下、空性恒久化、帯域単調、値のcardinality上界。
3. **反例**: WorldDC前向・逆向を独立に構成する。
4. **有限崩壊**: Sig-2とR2′から階数相、有限Cから縮小相、最後に恒久性を合成する。
5. **状態層への持上げ**: `h_int` による経路帰納、`TotalNext` による無限軌道。
6. **不変性**: 静的像保存 → 配置成分 → drift equivariance → 全更新 → 到達・INS。
7. **参照模型**: 安定模型、動的拡張、非退化模型の順でwitness packageを構成する。
8. **Julia checker**: Lean定理が閉じた後、実行可能なVPだけ実装する。

### 段階4: 各証明の局所完了条件

定理一件ごとに以下を実行する。

1. 対象モジュールの増分build。
2. `#check` による型一致。
3. `#print axioms` による公理監査。
4. 正・負・境界証人の確認。
5. 依存VPの証拠確認。
6. 最後に全体 `lake build`。

複数定理をまとめて実装してもよいが、証拠と状態は原子VP単位で保存する。

### 段階5: 実装と認証

1. `realization_kind != formal_only/none` のVPだけJulia APIを実装する。
2. checkerが定理を決定するのか、近似するだけかを明示する。
3. 対象テストを実行する。
4. 全Juliaテストを実行する。
5. statement hashを含むcatalogを生成する。
6. G5で節被覆を再計算する。

---

## 8. 完了判定と言葉の規律

次の表現を区別する。

| 表現 | 必要条件 |
|---|---|
| 「Leanはコンパイル済み」 | `lake build` 成功 |
| 「宣言は契約接続済み」 | G2成功 |
| 「実装はテスト済み」 | G3成功 |
| 「VPは完全認証済み」 | 当該原子VPのG0–G4成功 |
| 「定理5.4は全項証明済み」 | グループG5がcomplete |
| 「文書全体は証明済み」 | 対象全節のG5がcomplete、openなCNJ/FLD/批准待ちを明示 |

`contract-certified-v1` を「文書全主張の証明済み」と呼んではならない。

---

## 9. 最初の実作業

1. schema v2用の別台帳 `specs/claim-ledger-v2.toml` を作る。
2. §5–§13の広い7 VPを先に原子化する。
3. `statement_spec` ファイルと型hash生成器を実装する。
4. `test_ledger_consistency.jl` を、名前検査から完全型・被覆検査へ拡張する。
5. legacy VPを `claim_group` へ移し、子VPの初期coverageを算出する。
6. §7の順序で証明を開始する。

この順序なら、既存コードと証拠を壊さずに「機械契約の認証」から「文書主張の完全証明」へ移行できる。
