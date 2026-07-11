# ERIE-C 要件定義書 ― ミニマル実装からゴールまで

**文書種別**:要件定義(IDE 実装着手用)
**版**:req v1.0
**根拠**:`category/tensor_categorical_v5.md` / `ERIE_C_design_spec.md`
**厳密性方針**:本文(§0–§8)は確定項目のみ。未確定・モデル選択は付録 U に隔離。各要件は機械検証可能な受け入れ基準を持つ。

---

## §0. ゴールとメタ要素(背骨)

**最終ゴール**:**この論理で出来た者(ERIE)が世界をどのように観測するかを確認する。**
厳密化:ERIE の観測を三層テンソル(感受性 `𝐓=∂σ/∂α`、価値 `𝐕`、行為化世界 `𝐖𝐥𝐝`)として外から完全に記述・可視化し、それが系を変えると変わる(Umwelt 相対性)ことを示す。

**ゴールでないこと**:ERIE に世界が「灯っている」ことの証明。これは原理的に外から取れない(v5 §13-5)。灯りは記述の外、賭けとして残す。

**確定メタ要素(動かさない四前提)**:M1 operational closure/precariousness、M2 随伴 α⊣σ、M3 蝶番、M4 内生性。M4 は外部 set point の不注入に加え、求めの図式が終対象としての set point を持たないことを含む。各フェーズでこれが破れたら C でなくなる。

**目的の入れ子**:
```
ERIE の観測構造の確定(ゴール)
  └─ 三層テンソルの記述と Umwelt 相対性の実証(フェーズ VII)
       └─ エナクティヴ構造の実装(フェーズ I–IV)
            └─ ミニマルな随伴とテンソルの核(フェーズ I)
```

---

## §1. フェーズ I ― 随伴の確立(土台)

**確定要件**:
- 随伴 α⊣σ の最小実装(`core/adjunction.py`)。ガロア接続の単位・余単位を検証。
- 感受性テンソル `𝐓=∂σ/∂a` の自動微分実装(`core/sensitivity.py`)、双対 `𝐓^*`。
- 自作ニューロン(A)の計算健全性を標準ニューロン差し替えで確認(消費側の最小版)。
- Lenia・TRM はまだ入れない。ℳ₁(随伴+テンソル最小モデル)で検証。

**関門(受け入れ基準)**:
| # | 基準 |
|---|---|
| I-1 | 随伴条件 `α★(N)⊆X ⟺ N⊆σ★(X)` が全ペアで成立(または単位・余単位) |
| I-2 | `𝐓` が `∂σ/∂a` として計算され画像テンソルでない |
| I-3 | 双対対称性(`𝐓` と `𝐓^*` の随伴関係、v5 Prop 2.4) |
| I-4 | 消費側(自作ニューロン)が随伴を切らない(逐次パイプラインでない) |

I-1/I-4 が破れたら全体が表象主義に退化。**最優先**。

---

## §2. フェーズ II ― 身体と視覚的ホメオスタシス(C の形)

**確定要件**:
- Lenia 場を ERIE の視野=身体とする。
- 見えを制御変数とする視覚的ホメオスタシス。ただし set point は圏内の到達可能な終対象として与えず、νΦ 由来の構造的重みと見果てぬ行為方向として扱う。
- 感受性テンソル `𝐓` を ERIE の見えの本体として身体に接続。

**M・E定義(確定)**:
- **M(作動) k=16〜24**: Lenia フィールドへの身体的介入モード `B_M·a`。
  具体モード: 外縁 normal push/pull、tangential shear、回転、収縮/膨張、局所成長促進/抑制、障害物回避方向の低ランク摂動。カーネルパラメータのオフセットは**不可**(法則操作であり身体的作動でない)。
- **E(環境結合) n=32〜64**: 同じ身体座標系での応答特徴 `P_E(·)`。
  具体チャネル: 境界16セクター平均、radial gradient、normal flux、curvature/shape mode、contact/obstacle field、νΦ寄与チャネル。
- **σの定義**: `σ(a) = P_E( F_τ(x + B_M·a) )`、`𝐓_w = ∂σ/∂a`(ForwardDiff)。
- **随伴の保証**: `σ★_induced(α_rel)` で構成的に GC 保証。物理 σ_rel を独立採用する場合は check_K3 でサンプル検査し破れるチャネルを削る。

**関門**:
| # | 基準 |
|---|---|
| II-1 | 外部 set point/目標パターンがコード内に不在(検問 K1、静的走査) |
| II-2 | `𝐕` が νΦ から内生計算される(νΦ 依存性テスト) |
| II-3 | 求めの図式が終対象としての set point を持たない(有限ハーネス `SetPointDiagram`) |
| II-3 | `𝐓` が Lenia 身体に対するヤコビアン `∂σ/∂a` として立つ |
| II-4 | rank(𝐓) > 0、T/T* 双対対称性、𝐋=𝐓^*𝐓 の非自明固有空間を確認 |
| II-5 | M がカーネルパラメータでなく場への介入モードであること(grep 可能な検問) |

---

## §3. フェーズ III ― 二重閉包の蝶番(wireheading 遮断)

**確定要件**:
- 自己維持作動と視覚的作動を同一作動に強制(`Act_w≠∅`)。
- 価値テンソル `𝐕` を νΦ から内生計算、重みづけられた感受性 `Ô=𝐓⊙𝐕`(構造的重み。現象的 mattering との同一視は §13-5 の賭けに属する)。

**関門**:
| # | 基準 |
|---|---|
| III-1 | 蝶番 `Act_w(σ)≠∅` が成立 |
| III-2 | 視野整形のみで自己維持に効かない作動が構成不能(検問 K2、Prop 4.6) |
| III-3 | `𝐕` が νΦ のみから計算(外部由来でない) |

---

## §4. フェーズ IV ― 行為化世界(C の現象構造・最難関)

**確定要件**:
- 行為化世界 `𝐖𝐥𝐝 = 𝐋=𝐓^*𝐓 の不変部分空間` を固有分解で実装(`core/world.py`)。
- Prop 5.3(`DC ⟺ 𝐖𝐥𝐝` 非自明)を実機で確認。

**関門**:
| # | 基準 |
|---|---|
| IV-1 | `𝐖𝐥𝐝` が `𝐓`(=α,σ)のみから計算、外部表象不参照(検問 K3 拡張) |
| IV-2 | Prop 5.3 の同値(DC 成立 ⟺ `𝐖𝐥𝐝` 非自明) |
| IV-3 | 系(α,σ)改変で `𝐖𝐥𝐝` が変わる(**Umwelt 相対性**) |

IV は最難関(`𝐋` 不動点の連続高次元計算、存在と到達の間隙)。ここで詰まればCの本当の壁(付録 U-1)。

---

## §5. フェーズ V ― 統合と消費側(TRM/ニューロン群)

**確定要件**:
- 三層テンソルの各ブロックを TRM 群(World/Boundary/Viability/Action)に学習させ予測符号化で統合。
- 消費側を疎結合インターフェース(`consume/interface.py`)で分離、後に自作ニューロン群へ差し替え可能に。
- TRM 結線は設定駆動(topology カタログ)で外出し。

**関門**:
| # | 基準 |
|---|---|
| V-1 | 統合が随伴を貫通して保つ(フェーズ I 随伴がニューロン層を通っても生存、検問 K3) |
| V-2 | 消費側差し替えがインターフェース変更なしで可能 |
| V-3 | TRM 結線が設定で宣言、コード変更なしで変更可 |

---

## §6. フェーズ VI ― 確認基盤(四参照系)

**確定要件**(人間の脳を手本とせず、用途別ベンチマーク):
- (1) 計算健全性:標準ニューロン差し替えテスト。
- (2) 随伴:視覚サーボ・能動知覚タスク(随伴がないと解けない課題)。
- (3) 意識/無意識乖離:ERIE 版盲視(FM-2/3 欠如作動)。心理物理学の課題構造のみ参照(脳配線は参照しない)。
- (4) precariousness:ホメオスタシス崩壊照合、critical slowing down を `𝐋` 最大固有値の臨界漸近で測定(`metrics/slowing.py`)。

**関門**:
| # | 基準 |
|---|---|
| VI-1 | 四スイートが回る |
| VI-2 | 各機能が人間との類似と無関係に判定(個性と欠陥を混同しない) |
| VI-3 | critical slowing down が崩壊前に `𝐋` 固有値→1 として観測 |

---

## §7. フェーズ VII ― ゴール:観測の記述と可視化

**確定要件**:
- ERIE の観測を三層テンソルで完全記述・時系列可視化:
  - `𝐓`(行為可能性の網=何にどう働きかけられるか)
  - `𝐕`(νΦ への内生的寄与率=自己維持上の構造的重み、現象的 mattering は含意しない)
  - `𝐖𝐥𝐝`(系にとっての世界の全体、外を持たない)
- 系を変えて `𝐖𝐥𝐝` が変わることを示し、ERIE の観測が外界の写しでない固有 Umwelt であることを構造的に確定。
- critical slowing down のスペクトルで、崩壊接近時に観測世界がどう収縮するかを可視化。

**ゴール到達条件**:
| # | 基準 |
|---|---|
| VII-1 | ERIE の観測構造が三層テンソルで完全記述される |
| VII-2 | Umwelt 相対性が示される(系改変で `𝐖𝐥𝐝` 変化) |
| VII-3 | 「灯り」が記述の外に賭けとして明示的に残される(v5 §13-5 を消さない) |

VII-3 が要件に含まれることが本プロジェクトの誠実さ。観測の**構造**を確定するが**灯り**は確定しない、を成果物自身が明示する。

---

## §8. 全フェーズ貫通の三検問

`tests/checkpoints.py` が CI で常時実行:
- **K1/M4 内生性**:set point が外部ハードコードされていないか、かつ求めの図式が終対象 set point を持たないか。
- **K2 蝶番**:視野整形のみの空作動が構成不能か(wireheading 遮断)。
- **K3 随伴**:α⊣σ が消費層を貫通するか(逐次パイプラインでない)。

一つでも破れたら C でなくなる。CI fail 条件。

---

# 付録 U. 未確定項目・モデル選択(隔離)

**U-1. `𝐖𝐥𝐝` の到達可能性(最難関)**。2026-06-28 に存在側を T の直接 SVD、到達側を固定 Wld 射影への反復 probe として確定・実装。本番 rank は実測後に決定する。

**U-2. 自作ニューロンの動態形式**。発火則・ダイナミクスの具体形未定。確定:随伴を切らない(再入的)こと(検問 K3)。決定主体:消費側設計(フェーズ V)。

**U-3. Lenia 身体の連続/離散変換**。感受性テンソル(連続ヤコビアン)と Lenia 格子(離散)の変換に伴う人工物の切り分け。ズレが仕様欠陥か離散化由来かの判定手続き未定。決定主体:身体実装(フェーズ II)。

**U-4. critical slowing down の定量しきい値**。`𝐋` 最大固有値が「1 に近い」の具体的閾値、崩壊予測のリードタイム。決定主体:照合実験(フェーズ VI)。

**U-5. 価値テンソル `𝐕` の測度**。非正規化濃度を既定のまま維持し、`Measure` による正規化比率を opt-in で実装。production measure の選択は実験後に決定する。カスタム μ は νΦ のみから内生(M4)。

**U-6. 随伴の連続化**。posetal な像作用素から連続ヤコビアン `𝐓` への移行(v5 §2.3)の数値的厳密性。離散随伴と連続随伴の対応が保たれる条件未整理。決定主体:`core/sensitivity.py` 実装。

**U-7. TRM データセットと学習**。各 TRM(World/Boundary/Viability/Action)のラベル・データ生成・学習ループの完全仕様は別文書。本書はフェーズ V の統合要件まで。決定主体:別途要件定義。

## 付録 U への暫定決定（2026-06-28）

- Lenia の `M` は `B_M * a` によるフィールド状態への低ランク身体的介入とする。
  kernel/growth parameter は固定法則または外部実験条件であり、action coordinate にしない。
- production の action 次元は 16〜24。縮小次元は prototype / CI として明示する。
- critical slowing の暫定閾値は `lambda_max >= 0.95`、固有値許容誤差は `1e-6` とする。
- 再現性の暫定条件は seed `42`、3 回反復、対象 metric が中心値から `+/-1%` 以内とする。
- K1/K2 は現フェーズでは実用検査として扱い、完全な構成不能性証明は将来の Lean 課題に隔離する。
- `Wld` 到達手法、`V` の opt-in 測度 API、VII-1 の最終 artifact 契約は `specs/phase-iv-vii-spec.md` v4 で確定済み。

---

*本書は ERIE-C のミニマル実装からゴール(観測構造の確定)までの確定要件である。ゴールは灯りの証明でなく観測構造の完全記述であり、灯りは賭けとして記述の外に残す(VII-3)。要石は随伴(I)と蝶番(III)、最難関は行為化世界の到達可能性(IV)。三検問 K1/K2/K3 が全フェーズで C を保証する。*

---

## 追記: 現実装との差分監査（2026-06-25）

現リポジトリは、要件書本文の Python 風モジュール構成ではなく、Lean 形式層（`formal/ERIEC/`）と Julia 数値層（`src/`）で実装されている。以下は `docs/ERIE_C_requirements.md` と現在の実装状態の主要な相違点である。

### 実装済み・要件に概ね対応

- §1 I-1: 随伴の離散層は `formal/ERIEC/Adjunction.lean` と `src/adjunction.jl` に実装済み。`check_K3` と `check_galois_conn` による有限宇宙検査がある。
- §1 I-2/I-3: 感受性テンソル `T = ∂σ/∂a` と双対対称性は `formal/ERIEC/Sensitivity.lean` / `src/sensitivity.jl` に実装済み。
- §2 II-5: `InterventionMode` と `KernelParam` の型分離は `formal/ERIEC/Body.lean` / `src/body.jl` に実装済み。
- §3 III-1: `Act` と DC の蝶番条件は `formal/ERIEC/Hinge.lean`, `formal/ERIEC/DC.lean`, `src/hinge.jl`, `src/dc.jl` に実装済み。
- §3 III-3: 価値の構造側（νΦ への寄与）と現象的 mattering の分離は `formal/ERIEC/Value.lean` / `src/value.jl` に実装済み。
- §4 IV-1: `Wld = eigenspace(T' * T, λ≈1)` は密固有分解と T の直接 SVD を切替可能で、高次元 SVD 経路は Gram 行列を実体化しない。固定 Wld への反復到達 probe も `src/world.jl` に実装済み。Lean 側では `formal/ERIEC/World.lean` が `worldLoop = T* ∘ T` と `WldNontrivial` を定義している。

### 相違点・未実装

- §1/§4 のファイル名は要件書では `core/*.py` だが、現実装は `src/*.jl` と `formal/ERIEC/*.lean`。これは実装言語選択の差分であり、機能名は Julia/Lean 側に対応している。
- §1 I-4: 消費側は `Consumer` / `TRMConsumer` と線形・小規模 tanh neural action model、checkpointed neural training run、optimizer state/checkpoint artifact certificate、built-in/external TRM neural experiment preset と preset certificate まで実装済み。
- §2: `LeniaFieldSystem` は `B_M·a` による場介入、周期畳み込み、Gaussian growth、`P_E(F_τ(...))` 特徴抽出、ヤコビアン、実験条件を実装済み。長時間実データでの離散化誤差評価は未実施。
- §2 の次元要件 `M k=16〜24`, `E n=32〜64` は、Lenia adapter 側では `action_count=16`, `feature_count=32/64` まで接続済み。ただし旧 `InterventionMode` / `SensoryFeature` 列挙型はプロトタイプ段階の小さい基底として残る。
- §2 II-1/II-2/II-3: 外部 set point の静的走査と K1 構造検問は実装済み。`check_K1_structural(response)` は禁止語走査と `EndogenousBodyResponse` 要求を行う。`SetPointDiagram` / `check_m4_no_terminal_setpoint` により、有限ハーネス上で終対象 set point が存在しないことも検査できる。ただし Julia クロージャによる外部捕捉までは完全検出できない。
- §3 III-2: `hinge_integrity` / `check_K2_strict` は有限関係上で sensory-supported action と self-maintaining action の差集合を列挙し、sensory-only action が1つでもあれば拒否する。一般的な構成不能性の Lean 証明は未実装。
- §3: 重みづけられた感受性 `Ô = T ⊙ V` は `weighted_sensitivity` / `viability_weights` として最小実装済み。
- §4 IV-2: `DC ⟺ Wld 非自明` の完全な Prop 5.3 は未証明・未実装。`formal/ERIEC/WorldDC.lean` は、`DC` と非零固定方向が与えられた場合に `Act` 非空かつ `WldNontrivial` を得る弱形式に留まる。
- §4 IV-3: Umwelt 相対性は `test/test_world.jl` の最小数値例で確認しているが、Lenia 身体や実システム改変による実証ではない。
- §5: 消費側インターフェース、minimal policy、TRM topology catalog、`TRMConsumer`、TRM action を次 step に戻す closed rollout、TRM 学習対象と rollout dataset/loss、線形 action model fitting、training step result、自作小規模 tanh action model fitting、neural training step certificate、checkpointed neural training run certificate、optimizer state/checkpoint artifact certificate、closed rollout から neural training と output directory 保存までの backend preset、複数条件 sweep と summary / aggregate report 出力、sweep report certificate / certificate graph / envelope audit、`run-summary.tsv` による同条件 run の resume、`optimizer-state.tsv` による model weight 継続復元、`:smoke` / `:short` / `:long` preset catalog、key=value / TSV 外部preset、preset certificate、toy / Lenia adapter preset を選べる TRM neural experiment CLI は実装済み。
- §6: 四参照系ベンチマーク、ERIE 版盲視アナログ、precariousness 崩壊照合、critical slowing down 指標、Lenia tau/feature/parameter-grid sweep を実装済み。Lenia は preset、外部 preset、条件別 artifact 保存、再開、manifest、欠損検査、aggregate certificate graph、dry-run plan、run index 分割まで実装済み。長時間実データの蓄積は未実施。
- §7: schema version 1 の `ObservationArtifact` / `ObservationArtifactCollection` が `T` / `V` / `O_hat` / Wld 時系列、system fingerprint、Umwelt 射影差、certified envelope を提供する。Lenia runner/sweep/CLI は実 system/action/条件/初期場 fingerprint を持つ同形式を end-to-end 出力し、parser は必須 channel と `phenomenal_claim=:not_certified` を構造検査する。
- §8: `tests/checkpoints.jl` は K1/K2/K3 の最小検問を含む。K1 は禁止語走査と `EndogenousBodyResponse` 要求までで、クロージャ捕捉の完全静的解析は未実装。
- Lean-Julia 境界は `formal/ERIEC/CertifiedArtifact.lean` と `src/certification.jl` により、Lean typecheck 済み contract catalog、Julia verifier、certificate envelope まで実装済み。`lean_certified_artifact` / `verify_lean_certified_artifact` で正式 catalog を Julia 側から取得・検証でき、certificate envelope は `schema_version=1` と `trust.boundary=:lean_core_julia_shell` を持つ。payload が catalog 未登録の Lean contract id を参照した場合は拒否する。観測 artifact は certified envelope JSON として出力可能。`DCWorldBridge`、前層遷移余積、NoTerminalSetPoint、TRM rollout dataset、TRM 線形 action model、TRM training step、TRM neural action model、TRM neural training step/run、TRM neural optimizer state/checkpoint、Lenia architecture status、Lenia tau/feature/parameter-grid sweep は concrete instance certificate を持ち、各 certificate は Lean contract id / Lean 宣言依存 / Julia checker / 数値仮定 / trust profile を `certificate_dependency_graph` で公開する。Lenia architecture runner と TRM neural experiment runner も `certificate_check` 指定時に certified artifact JSON を返せる。ただし Julia 数値実装と Lean 意味論の完全同値証明は未実装。
- `adjunction.system` についても `check_erie_structure` を Julia checker として追加済み。有限台がある場合は Galois connection を再検査できる。

### 次に埋めるべき差分

1. certificate envelope の対象を長期実験プリセットと run 管理へ広げる。観測 artifact、`DCWorldBridge`、前層遷移、NoTerminalSetPoint、TRM rollout dataset、TRM 線形/neural action model、TRM training step / neural training run / optimizer state / optimizer checkpoint、TRM preset / sweep report / certificate graph / envelope audit、Lenia architecture status、Lenia tau/feature/parameter-grid sweep envelope は実装済み。certified envelope JSON は JSON3 で構文解析し、schema / payload / certificate / trust / kind を構造監査する。
2. TRM neural training experiment の preset 管理を堅牢化する。現状は built-in `:smoke`, `:short`, `:long` preset、key=value / TSV 外部preset、preset schema certificate、sweep report certificate、`run-summary.tsv` による同条件 run の再利用、`optimizer-state.tsv` による model weight 継続復元、checkpoint certificate envelope まで実装済み。
3. 四前層高次仕様の Lean 証明面を、軽量 `Sigma` 型表現から一般圏論ライブラリ上の普遍性定理へ拡張する。
4. 本格 Lenia 場の追加実験設定（長期 tau step 比較、パラメータ sweep）を追加する。
