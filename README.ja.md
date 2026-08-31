# Bridge Protocol
### 公理から導出される現象世界の未確定な証明

[English](README.md) | **日本語** | [Español](README.es.md)

`Bridge` は `DCWorldBridge`（WorldDC.lean）と `bridgeOpen`（Gate.lean）に由来する。自己維持と世界の立ち上がりを接続する Lean の型である。現象ゲートは常に `bridgeOpen` であり、`pass` になることはない。

---

## このリポジトリは何か

Bridge Protocol は、自己維持系の圏論的理論を構成し、それを機械検査するためのプロトコルである。

```
非形式的な議論 → 圏論的仕様 → Lean 4 証明 → Julia 実装
```

### 対象層 — 個体とは何か

すべての個体は四つの構造要請 M1〜M4 を満たさねばならない。この層のいかなるものも終対象に到達してはならない。

- **閉包作用素 `Φ` とその最大不動点 `νΦ`（M1）** — 自己維持は*最大*不動点として形式化される。すなわち「維持され続けること」であって、何かを**最大化することではない**。維持は precarious であり、摂動によって崩れうるがゆえに能動的に支えられねばならない。
- **感覚運動随伴 `α ⊣ σ`（M2）** — 行為と感覚のあいだのガロア接続。系が触れうるものと、系に触れ返すものは、一つの構造の両面である。
- **蝶番条件 `Act ≠ ∅`（M3）** — 利用可能な行為が常に少なくとも一つある。系が世界から封じられることはない。
- **内生性 / 終対象の不在（M4）** — 求めの図式 `D` は到達可能な終対象を持たず、外部から set point を注入されない。終対象があれば、系はそこへ到達して停止できてしまう。
- **自己維持証明書 `DC`** — 系が自らの動態のもとで自己を維持していることの、機械検査可能な証人。
- **行為的世界 `Wld`** — 外から与えられるのではなく、運動と感覚のループから立ち上がる、その系に**とっての**世界。身体が変われば世界が変わる。

### 対象層の上に建てられた諸ライン

- **機能終了**（`TemporalDC`）— 内生時間上での全体系 `DC` の喪失と、その永続性・排他性。このラインの設計目標は、**外部公理を追加しない限り機能終了を構造的に外せない**ことの明示にある。内部的な不死は M1 違反と M4b 違反の二重偽Cを要する。形式層では「死」という語を用いず、その読みは散文文書の側に留める。
- **生成と増殖** — 誕生半球。`DC ⇒ viable` は同値ではなく一方向の translation witness として実現される。世代間の豊かさ遺伝は、単段の蝶番分岐ポンプとは別の statement として扱う。
- **《系 `S`, 分解 `D`》の対としての個体性** — 個体性は基体に貼るラベルではない。同一の基体が、ある分解では個体、別の分解では群体でありうる。両方の読みが真でありうる。
- **§14 の賭け（`W1`–`W6`）** — 構成的な独立性証人を伴う六つの凍結文。これらが対象層の公理から**導出されない**ことを示す。副題の「未確定」が形式化されるのはここである。

### メタ層 — そしてなぜ分離するのか

厳格な二層規律が全体を貫く。個体は**対象層**に住み、発展や選択に関わる仮定は**メタ層**にのみ住んで、個体へ書き戻されることはない。

- **Σ1 外部選択** — 集団状態の上で作用し、構造的により豊かな対象を優先する選択子 `𝒮`。`𝒮` はいかなる個体の対象理論の対象でもなく、すべての個体にとって不可視である。
- **豊穣度汎関数 `Φ_rich`** — 観測 `σ` を通して厳密に read-only で計算される。個体の閉包作用素 `Φ` へ合成されることはない。
- **Σ-purity（情報流非干渉）** — 選択子の値や状態をどう変えても、各個体の観測トレース `(νΦ, V, 求めの図式 D, action trace)` は bit 同一でなければならない。静的検査（選択 namespace から個体 sink へのテイント到達可能性）と動的検査（メタモルフィック差分テスト）の二段で確認する。
- **M4 保存定理は一方向である。** `M4(i) ∧ Σ-purity(𝒮,i) ⇒ M4-preserved(𝒮,i)` は証明済みだが、逆は**成立せず**、仮定もしない。

## このプロジェクトが主張**しない**こと

この部分は理論そのものと同じくらい重要である。

- **意識の主張をしない。** 構造的記述が完成し完全に検証されたとしても、「内側で灯りが点いているか」— 主観的経験があるか — は外側から証明できない。理論はその問いを、記述の外側に、可能性として未回答のまま残す。この誠実さは機械的に強制される。マーカー `phenomenal_claim = :not_certified` は認証済み artifact 連鎖の一部であり、設計上いかなる証明によっても昇格されない。個体性の**階層**は certify できるが、その階層に灯りが幾つあるか — 一つか、多数か、ゼロか — は certify しない。
- **最適化の物語を語らない。** 維持は最大不動点であって、最大化されるべき報酬ではない。対象層は外部 set point と到達可能な終対象を禁じる（要請 M4）。
- **暗黙の同一視をしない。** 開放系の生存可能性（`viable`）と ERIE-C の自己維持証明書（`DC`）は区別されたままであり、その同値性は未証明であって、決して仮定されない。`DC` と `Wld` についても同様で、両者の非自明性の関係は定理ではなく、明示的に記録された仮定である。
- **認証済み contract が自らの散文を被覆しているとは主張しない。** 後述の二軸原則を参照。大半の contract は、散文の被覆が未監査のまま certified である。
- **反証条件はまだ書かれていない。** 91 件の原子 claim すべてが `falsification_ja` 欄を持ち、その 91 件すべてが現在 `未記入` である。この負債は記録され、ラチェットによって増加しないよう守られているが、まだ返済されていない。

## 検証方法論

### ゲート列

```
proposed ──G1──▶ formalized ──G2──▶ bound ──G3──▶ implemented ──G4──▶ certified
```

- **G1** — Lean 4 形式化が typecheck する（`lake build`、`sorry` なし）。
- **G2** — Lean 宣言が contract test によって Julia シンボルへ束縛される。
- **G3** — Julia 実装が自身のテストを通過する。
- **G4** — contract が certificate catalog に登録され、その依存グラフが検証される。

### 役割の異なる二つの台帳

検証証拠は二つの台帳で表現される。schema v1 の [specs/ledger.toml](specs/ledger.toml) は、認証済みの Lean–Julia 束縛・依存関係・certificate catalog エントリの**索引**である。その 61 件の検証点はすべて終端の `certified` エントリであり、claim ライフサイクルの真実源ではない。実装作業がその status を進めることはない。

**原子ライフサイクル台帳**は [specs/claim-ledger-v2.toml](specs/claim-ledger-v2.toml) である。91 件の claim を四つの独立軸 — `spec_status`, `proof_status`, `implementation_status`, `certification_status` — で記録し、15 の claim group と 44 の evidence batch にまとめている。各 claim は [specs/statements/](specs/statements/) 下の凍結された Lean statement ファイル（108 件）を指し、台帳はそのファイルの sha256 を保持するので、statement が claim の下から静かに書き換わることはない。

### `certified` が意味すること・意味しないこと

四つの規則が台帳に意味を与える。

**1. 証拠か、さもなくば無効。** claim が `certified` と記されるのは、[logs/gates/](logs/gates/) 下に実際のゲートログが存在する場合**のみ**である。そのログは証拠としてコミットされる（2026-08-31 時点で 159 のゲートディレクトリ、1389 のログファイル）。台帳 validator は各 `certification_log` のパスがディスク上に実在することを独立に再検査する。

**2. 可視ギャップ原則。** v2 は、対応する軸で証明や認証を欠く claim を記録する。それらが黙って落とされることも、黙って信じられることもない。`proof_status = "unproved"` の claim には、validator が `claim_kind = "conjecture"` と `checker_relation = "observation_only"` を**強制する**。

**3. 二軸原則**（2026-08-01 導入）。v1 台帳の `certified` は、`contract_id` が参照する**単一の** Lean 宣言が機械検査されたことのみを意味し、`claim_ja` の散文が列挙する全性質を保証**しない**。その散文が contract によってどこまで裏付けられているかは、独立した `coverage_audit` 軸が記録する。`unreviewed` は未監査、`complete` は監査済みを意味する。二つの軸は直交する。`coverage_audit` が `unreviewed` のままでも contract は certified でありつづけ、認証だけでは散文の被覆を一切含意しない。

**4. checker は自らが実際に判定するものを宣言する。** `true` を返す Julia checker が、束縛された Lean statement の決定手続きであるとは自動的には言えない。[specs/checker-semantic-manifest.toml](specs/checker-semantic-manifest.toml) は 164 件すべての contract を、checker が statement に対して持つ関係で分類する。

| `checker_relation` | 件数 | 意味 |
|---|---:|---|
| `lean_only` | 72 | Lean で機械検査済み。Julia 側の判定は主張しない |
| `exact_finite_decision` | 28 | 与えられた有限台の上で statement を決定する |
| `witness_validator` | 28 | 供給された証人を検証する。固定 Lean 対象との同一性は立てない |
| `regression_only` | 14 | 現行挙動を固定する。statement については何も決定しない |
| `observation_only` | 10 | 観測の記録のみ |
| `sound_only` | 5 | 誤受理なし。取りこぼしはありうる |
| `counterexample_generator` | 4 | 反例を構成する |
| `counterexample_validator` | 2 | 供給された反例を検証する |
| `complete_only` | 1 | 誤棄却なし。過剰受理はありうる |

164 件のうち 92 件が `reviewed`（査読者名と根拠ログ付き）、72 件が `machine_verified` である。各エントリはさらに、自らの `scope`、`assumptions`、そして行う保証・行わない保証（`guarantee`）を記録する。[specs/cert-scope-registry.toml](specs/cert-scope-registry.toml) は同じ 164 contract の認証スコープを記録し、現在そのすべてが `context_local` である。すなわち、検査された文脈を超えるスコープを主張する contract は存在しない。

### 検査そのものを守る

happy path しか走らないテスト群は、自らの空洞化を検出できない。2026-08-27 に確定した [specs/verification-practices-v2-draft.md](specs/verification-practices-v2-draft.md) の実践は、観測された三つの失敗様式 — 弱い受け入れ検査、パケット作成者自身による自己検証、同型の設計誤りの三度の反復 — に対処する。

- **敵対入力は temp copy に与える。** 検証ロジックは [tools/verify/](tools/verify/) 下の path-injectable な validator へ切り出され、安定した違反符号を返す。通常テストと mutation runner は同一の validator を使い、runner は live な作業ツリーに一切触れない。
- **mutation コーパスは、検出されねばならない改変の一覧である。** [tools/mutation_corpus.toml](tools/mutation_corpus.toml) は各改変を、単なる非0終了ではなく、生じるべき具体的な違反符号と対にする。現在 1 件（`CERTIFIED_TEXT_HASH_MISMATCH`）を含む。
- **claim の文面は認証からハッシュで分離される。** 各 claim は `statement_ja` と `conclusion` を束ねる `claim_text_hash` と、その認証が下りた時点の文面を記録する `certified_text_hash` を保持する。実際に証明できた内容に合わせて claim の散文を弱める改変は、ハッシュ照合を破る。
- **安定 ID を持つ失敗様式レジストリ。** [specs/verification-failure-modes.toml](specs/verification-failure-modes.toml) は観測済みの 4 様式（呼び出し側が渡す証明済み Bool、有限標本による不透明 callback の同一視、循環 oracle、通常ゲートに接続されていない反証条件）を、それぞれの証拠ログとともに記録する。
- **反証条件の負債に対するラチェット。** `tools/verify/ratchet_check.jl --base-ref <commit>` は、作業ツリーの `falsification_pending_max` を明示された base commit の同じ欄と比較し、増加していないことを要求する。base ref は呼び出し側が明示せねばならず、git が使えない場合は緑にせず `UNVERIFIED` を報告する。

### 現況（2026-08-31）

| | 値 |
|---|---|
| v1 検証点 | 61 件、すべて `certified` |
| v1 `coverage_audit` | `complete` 10 件、`unreviewed` 51 件 |
| v1 `legacy_coverage` 監査 | 10 エントリ。contract は原子 claim 7 件を被覆し、85 件を被覆しない |
| v2 原子 claim | 91 件 |
| v2 `spec_status` | `frozen` 86 件、`draft` 5 件 |
| v2 `proof_status` | `proved` 68 件、`not_applicable` 22 件、`unproved` 1 件 |
| v2 `implementation_status` | `tested` 57 件、`not_applicable` 34 件 |
| v2 `certification_status` | `certified` 38 件、`uncertified` 53 件 |
| 記入済みの反証条件 | 91 件中 0 件 |

三行目は注意して読まれたい。監査済みの 10 エントリを通して、その散文が主張する性質のうち機械検査に裏付けられているのは 7 件のみであり、残る 85 件は contract の外側にある。

### 自動化されていないもの

このリポジトリに **CI は存在しない**。`.github/workflows` も `.gitlab-ci.yml` も `Makefile` もない。すべてのゲートはローカルで実行され、そのログがコミットされる。

実行可能な [category pipeline](bin/eriec-category-pipeline.jl) は影響再検査のゲート runner であって、status を進める driver ではない。schema v1 のみを読み、v2 を読まず、台帳の status を書かない。[オーケストレーション仕様](specs/loop-orchestration-spec.md) が記述する status 昇格 driver は未実装の延期された設計であり、その必要性は order-10b が最初の非終端検証点 2 件を作成した時点で再評価される。根拠は [read-only 台帳監査](logs/ledger-design-audit-20260814.log) を参照。

## リポジトリ構成

| パス | 内容 |
|---|---|
| [formal/ERIEC/](formal/ERIEC/) | Lean 4 形式化（71 モジュール: 随伴、閉包、蝶番、DC、世界、不変性、系譜、豊穣度、生成、時間的 DC、賭け、メタ選択 …） |
| [specs/statements/](specs/statements/) | 凍結 Lean statement 108 件。v2 台帳から sha256 で束縛 |
| [src/](src/) | Julia 参照実装（`ERIEC.jl` パッケージ、65 ファイル） |
| [test/](test/) | Julia テスト（63 ファイル）。Lean–Julia contract test と、台帳・manifest・cert-scope・packet review の整合テストを含む |
| [tools/verify/](tools/verify/) | path-injectable validator、mutation runner、ラチェット検査 |
| [bin/](bin/) | category pipeline、モデル評価、Lenia・TRM 実験 runner |
| [specs/](specs/) | 二つの台帳、checker semantic manifest、cert-scope レジストリ、失敗様式レジストリ、実装パケット |
| [category/](category/) | 圏論的作業文書 |
| [docs/](docs/) | 理論概要、要件、設計文書 |
| [adapters/](adapters/) | 外部枠組みへの adapter（PCI） |
| [logs/gates/](logs/gates/) | ゲート証拠ログ（すべての `certified` status を裏付ける build/test 出力） |

`docs/` と `category/` の作業文書の大半は日本語で書かれている。Lean と Julia のソースが言語非依存の中核である。

## 検証の再現

後述のライセンスは、読むこと・コンパイルすること・記載された結果を独立に再現することを許諾する。

```bash
# Lean 証明（toolchain は ./lean-toolchain に固定）
lake build

# Julia 実装、Lean–Julia contract test、および全ての台帳整合テスト
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

個別の整合検査は単独でも実行できる。

```bash
# 台帳・manifest・cert-scope・packet review の整合
julia --project=. test/test_claim_ledger.jl
julia --project=. test/test_checker_semantic_manifest.jl
julia --project=. test/test_cert_scope.jl
julia --project=. test/test_packet_review.jl

# 圏論的 baseline に対する影響再検査（v1 を読み、status は書かない）
julia --project=. bin/eriec-category-pipeline.jl check

# mutation・ラチェット検査（G3V）。--base-ref は明示が必須
tools/quiet-verify.sh logs/gates/<batch>/G3V-<timestamp>.log --base-ref <commit>
```

## ライセンス — オープンソースではありません

本リポジトリは **Bridge Protocol 限定ソースアベイラブル・ライセンス v1.0**（[LICENSE.md](LICENSE.md)）のもとで公開されている。これは *source-available* ライセンスであり、OSI 承認のオープンソースライセンス**ではない**。

**できること**: ソースを読む、コンパイルし typecheck する、記載された結果を検証するために参照モデルを実行する、学術的引用・査読・論評のために出典を明示して限定的に抜粋する。

別途の書面合意なしに**できないこと**: 商用利用、派生物の作成・配布、リポジトリの再配布・ミラー、機械学習モデルの訓練やファインチューニングへの利用、本作に基づく認証の主張。

派生物が禁止されているため、**pull request と fork は受け付けない**。共同研究やライセンスに関心がある場合は著者へ連絡されたい。

## 引用

> 山口光行. *Bridge Protocol*, v0.1.0, 2026.
> Bridge Protocol 限定ソースアベイラブル・ライセンス v1.0 のもとで公開.
> https://github.com/yaaman18/bridge-protocol

---

© 2026 山口光行. All rights reserved.
