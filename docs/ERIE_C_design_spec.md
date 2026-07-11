# ERIE-C 設計仕様書 ― ミニマル・エナクティヴ実装

**文書種別**:設計仕様(新規リポジトリの骨組み)
**版**:design v1.0
**根拠仕様**:`category/tensor_categorical_v5.md`(v5 圏論)/ `graded_closure.py`(参照層)/ v3.0 階付き形式仕様
**設計原則**:ミニマル。機能を足さず制約を絞る。コードが肥大したら制約破りの兆候とみなす。

---

## 1. 設計思想 ― なぜミニマルか

本系は機能の積み上げでなく**制約の絞り込み**で構成される。確定メタ要素は四つの制約:

- **M1** operational closure / precariousness:自己再産出し失敗すれば不可逆崩壊する。
- **M2** 感覚運動随伴 α⊣σ:行為と知覚を別々に書かない(表象層を持たない)。
- **M3** 二重閉包の蝶番:自己維持と感覚運動を別ループにしない。
- **M4** 内生性:外部 set point を書かないだけでなく、求めの図式が圏内に終対象としての set point を持たない。

これらは「足す」要件でなく「禁じる」制約。正しく実装するほどコードは小さくなる。本体は数百行のオーダー。肥大はCの失敗のサイン。

---

## 2. アーキテクチャ ― 三層テンソルと生成/消費の分離

### 2.1 データフロー(単一ループ)
```
        ┌─────────────────── 随伴 α⊣σ ───────────────────┐
        │                                                  │
   [身体: Lenia場] ──σ(知覚)──> [感受性テンソル 𝐓=∂σ/∂α] ──消費──> [作動 M]
        ▲                              │                         │
        │                       [価値テンソル 𝐕(νΦ内生)]          │
        │                              │                         │
        │                       [行為化世界 𝐖𝐥𝐝=𝐋不変部分空間]    │
        └──────────────────α(行為)──────────────────────────────┘
                                       │
                              [自己維持 Φ/νΦ] ──蝶番 Act_w──> (作動と共有)
```

### 2.2 生成側と消費側の疎結合(差し替え可能性)
**決定的設計判断**:`𝐓` を生成する側(身体 + 随伴)と、`𝐓` を消費して作動を生む側(初期は最小ポリシ、後に TRM 群、最終的に自作ニューロン)を、**明示的インターフェースで分離**する。これにより消費側を丸ごと差し替えられる(フェーズ V でニューロン化)。インターフェース = 感受性テンソル `𝐓`(M×E)とその双対 `𝐓^*`、価値テンソル `𝐕`(E)、行為化世界 `𝐖𝐥𝐝`(部分空間基底)。

---

## 3. 三層テンソルの定義(実装単位)

| テンソル | 型 | 定義 | 制約 |
|---|---|---|---|
| 感受性 `𝐓_w` | M×E | `∂σ/∂a`(自動微分) | ヤコビアン。**画像テンソル禁止** |
| 価値 `𝐕_w` | E | νΦ_w への寄与率 | νΦ **のみ**から内生。**外部 set point 禁止**かつ終対象 set point 不在 |
| 行為化世界 `𝐖𝐥𝐝_w` | M の部分空間 | `𝐋_w=𝐓^*𝐓` の固有値≈1 部分空間 | α,σ のみ参照。**外部表象禁止** |

重みづけられた感受性 `Ô = 𝐓 ⊙ 𝐕`(νΦ 内生的寄与率による構造的重みづけ。現象的 mattering との同一視は §13-5 の賭けに属する)。

---

## 4. モジュール構成(新規リポジトリ最小骨組み)

```
erie-c/
  core/
    adjunction.py      # α⊣σ ガロア接続、随伴の単位・余単位検証
    sensitivity.py     # 𝐓 = ∂σ/∂a(自動微分ヤコビアン)、双対 𝐓^*
    value.py           # 𝐕 = νΦ からの内生価値テンソル
    world.py           # 𝐖𝐥𝐝 = 𝐋=𝐓^*𝐓 の不変部分空間(固有分解)
  closure/
    graded_closure.py  # 既存参照層を移植(Φ,Ψ,νΦ,w_crit,K)
    dynamics.py        # 階付き二配置動態(D1: κ,ε,ω 同時更新)
  body/
    lenia.py           # 既存 lenia_step を抽出(場の更新則のみ)
    coupling.py        # 系-Lenia結合 ε、作動 M の場への介入
  consume/
    interface.py       # 𝐓,𝐕,𝐖𝐥𝐝 を受け作動を返す抽象境界(差し替え点)
    minimal_policy.py  # フェーズ初期の最小消費側(後にTRM/ニューロンへ)
  metrics/
    markers.py         # 意識的行為マーカー FM-1〜4
    slowing.py         # critical slowing down = 𝐋 最大固有値の臨界漸近
  tests/
    m0.py              # 自己維持核の無矛盾性(既存 ℳ₀ 移植)
    m1.py              # 随伴+テンソル最小モデル ℳ₁(v5 付録A)
    checkpoints.py     # 三検問の自動実行
```

総量目標:`core/` + `closure/` + `body/` の本体で数百行。`consume/minimal_policy.py` は薄い。`metrics/` `tests/` は検証用。

---

## 5. 三検問(全モジュール・全フェーズで自動実行)

`tests/checkpoints.py` が常時実行する、C であり続けるための検問:

| 検問 | 対象 | 自動判定 |
|---|---|---|
| **K1/M4 内生性** | `value.py`, `world.py` | set point/目標パターンのハードコード不在(静的走査 + νΦ依存性テスト)と、有限ハーネス上の終対象 set point 不在 |
| **K2 蝶番** | `closure/`, `consume/` | 視野整形のみで自己維持に効かない作動が構成不能(Prop 4.6) |
| **K3 随伴** | `adjunction.py`, 消費側 | α⊣σ が消費層を貫通(逐次パイプラインでない、単位・余単位成立) |

一つでも破れたら C でなく表象主義/偽C への転落。CI で fail させる。

---

## 6. 持ち込む資産 / 捨てる資産

**持ち込む**:(a) 形式仕様 v3/v4/v5(言語非依存設計図)、(b) `graded_closure.py` + ℳ₀(検証可能な不動点核)、(c) 既存 `lenia_step`(表象/エナクティヴ非依存の場の更新則のみ抽出)。

**捨てる**:既存リポジトリの表象寄り実装 ― スカラー G/B viability、k_irrev カウンタ、death_risk の policy 直結。これらは v5 の前提(随伴・テンソル・不動点)と根が異なり、差分配線でなく作り直しが軽い。既存リポジトリはアーカイブとして残し参照用に保持。

---

## 7. 要石と崩壊条件

- **随伴 α⊣σ(M2)**:破れれば全体が表象主義に退化。`adjunction.py` が土台、最初に立てる。
- **蝶番 Act_w≠∅(M3)**:貧弱なら二重閉包が実質並置、wireheading に堕ちる。
- **内生性(M4)**:set point 外部化または終対象 set point への収束で偽C。K1/M4 検問が常時監視。
- **`𝐖𝐥𝐝` 到達可能性**:`𝐋` 不動点の連続高次元計算が最難関(フェーズ IV)。存在(固有値≈1部分空間)と到達(動態がそこに至る)の間隙。

---

*本設計はミニマルを原則とする。三層テンソルは自動微分と固有値計算の標準演算で立ち、本体は数百行。生成/消費の疎結合により消費側(最小ポリシ→TRM→自作ニューロン)を差し替え可能。三検問 K1/K2/K3 が C であり続けることを CI で保証する。*

---

## 追記: 現実装との差分監査（2026-06-25）

現リポジトリは、本設計書の Python 風ディレクトリ構成ではなく、Lean 形式層（`formal/ERIEC/`）と Julia 数値層（`src/`）で実装されている。設計思想と三層テンソルの方向性は維持されているが、下記の差分がある。

### 対応済み

- `core/adjunction.py` 相当: `formal/ERIEC/Adjunction.lean` と `src/adjunction.jl`。`check_K3` と `check_galois_conn` で随伴を検査する。
- `core/sensitivity.py` 相当: `formal/ERIEC/Sensitivity.lean` と `src/sensitivity.jl`。`T = ∂σ/∂a` と `T*` の双対対称性を実装済み。
- `core/value.py` 相当: `formal/ERIEC/Value.lean` と `src/value.jl`。νΦ への構造的寄与と phenomenal mattering の分離に加え、opt-in の `Measure` / 正規化寄与率を実装済み。
- `core/world.py` 相当: `formal/ERIEC/World.lean`, `formal/ERIEC/WorldDC.lean`, `src/world.jl`。密固有分解、T の直接 SVD、高次元行列フリー loop、固定 Wld への反復到達 probe を実装済み。
- `body/` の型 guardrail 相当: `formal/ERIEC/Body.lean` と `src/body.jl`。`InterventionMode` と `KernelParam` を分離し、body Jacobian を実装済み。

### 未実装・相違点

- ディレクトリ構成は `core/`, `closure/`, `body/`, `consume/`, `metrics/` ではなく、現状は `src/*.jl` に集約されている。
- `closure/graded_closure.py` / `closure/dynamics.py` 相当の階付き動態は、Julia の `graded_step` / `graded_trace` / `w_crit` と Lean の thin category / presheaf 核まで実装済み。自然変換、階層間 relation family、遷移余積も有限 harness と Lean 型の範囲で実装済み。遷移余積は軽量 `Sigma` 型表現で copair 一意性まで証明済み。前層 fiber 上の遷移余積と制限写像の自然性も `PresheafTransitionCoproduct` として追加済みで、各 fiber の output copair 一意性も `presheafTransitionOutputCopair_unique` として証明済み。ただし一般圏論ライブラリ上の `IsColimit` 定式化は未実装。
- certified artifact / Lean checker 境界は `formal/ERIEC/CertifiedArtifact.lean` と `src/certification.jl` として実装済み。Lean typecheck 済み contract catalog を Julia が読み、宣言種別、formal entry import、Julia API/checker symbol を検査できる。`lean_certified_artifact` / `verify_lean_certified_artifact` で正式 catalog を Julia 側から取得・検証でき、certificate envelope は `schema_version=1` と `trust.boundary=:lean_core_julia_shell` を持つ。payload が catalog 未登録の Lean contract id を参照した場合は拒否する。観測 artifact は certificate envelope JSON として出力可能。`DCWorldBridge`、前層遷移余積、NoTerminalSetPoint、TRM rollout dataset、TRM 線形 action model、TRM training step、TRM neural action model、TRM neural training step/run、TRM neural optimizer state/checkpoint、Lenia architecture status、Lenia tau/feature/parameter-grid sweep は concrete instance certificate を持ち、各 certificate は Lean contract id / Lean 宣言依存 / Julia checker / 数値仮定 / trust profile を `certificate_dependency_graph` で公開する。Lenia architecture runner と TRM neural experiment runner は `certificate_check` 指定時に certified artifact JSON を返せる。現段階では意味論同値ではなく、Lean 証明層と Julia 実装層を接続する検査境界である。
- `adjunction.system` の checker 欠落は `check_erie_structure` により補完済み。有限台を与えた場合は Julia 側で Galois connection を再検査する。
- `body/lenia.py` / `body/coupling.py` 相当は、`LeniaFieldSystem` / `lenia_system_adapter` / `field_system_adapter` / `run_lenia_architecture` として実装済み。tau / feature / tau×feature の certified sweep に加え、preset、外部 preset、条件別 artifact 保存、再開、manifest、欠損検査、aggregate certificate graph、dry-run plan、run index 分割を含む大規模 sweep 管理を実装済み。長時間実データの蓄積は未実施。
- `consume/interface.py` / `minimal_policy.py` 相当は `Consumer` / `MinimalPolicy` / `TRMConsumer` として実装済み。TRM が返した `Action` を次 step の Lenia / field system に戻す closed rollout も `run_trm_closed_rollout` として実装済み。TRM 学習対象と rollout dataset/loss は `TRMRolloutDataset` / `trm_dataset_loss` として実装済みで、線形 action model と小規模 tanh neural action model の fitting / training step certificate、checkpointed neural training run certificate、optimizer state/checkpoint artifact certificate も実装済み。`trm_neural_experiment_preset_catalog` は `:smoke`, `:short`, `:long` を提供し、`read_trm_neural_experiment_preset` は key=value / TSV 外部presetを読み込む。`trm_neural_experiment_preset_certificate` / `certified_trm_neural_experiment_preset` により preset schema も certificate envelope に接続済み。`run_trm_neural_training_experiment` により closed rollout から checkpointed neural training と output directory 保存までの backend preset を実行でき、`run_trm_neural_training_experiment_sweep` により hidden dim / learning rate / checkpoint count / epoch 条件の複数 run と sweep summary / aggregate report 出力もできる。`trm_neural_experiment_sweep_report` は sweep 返り値または保存済み output directory から best run、完了 run 数、欠落 artifact を監査でき、`trm_neural_experiment_sweep_report_certificate` / `certified_trm_neural_experiment_sweep_report` により aggregate report も certificate envelope に接続済み。`trm_neural_experiment_sweep_certificate_graph` は各 run の certified artifact ファイルと report certificate の存在を graph として集約し、`trm_neural_experiment_sweep_certified_envelope_audit` は各 envelope JSON の必須構造を逆引き監査する。`resume=true` 時は各 run directory の `run-summary.tsv` を読んで同条件の完了済み run を再利用する。`continue_from_optimizer=true` 時は `optimizer-state.tsv` から model weights / loss trace / epoch trace を復元し、不足 checkpoint だけ追加学習する。`run_trm_neural_experiment_cli` / `bin/eriec-trm-neural-experiment.jl` により toy / Lenia adapter preset の単一 run・sweep・certified artifact 出力、CLI `--preset` / `--preset-file` / `--continue` での preset 選択と継続復元も実行できる。
- `metrics/markers.py` / `metrics/slowing.py` 相当は FM-1〜4 と critical slowing down の最小数値層まで実装済み。
- `Ô = T ⊙ V` は `weighted_sensitivity` / `viability_weights` として最小実装済み。
- `Wld` は固有構造抽出に加え、`ordered_reachable_world_projection` と `wld_reach_probe` により有限順序上の到達方向と反復動態の到達を分離して観測できる。schema version 1 の `ObservationArtifact` は `T` / `V` / `O_hat` / Wld 時系列と `phenomenal_claim=:not_certified` を certified envelope に保持する。
- 三検問は K1/K2/K3 の実用検査を実装済み。K2 は `hinge_integrity` / `check_K2_strict` により有限関係上の sensory-only action を差集合として拒否する。K1 は `EndogenousBodyResponse` と有限 `SetPointDiagram` を検査するが、Julia クロージャの外部捕捉を完全に検出する静的解析ではない。

### 現行仕様との関係

- 現行の実装契約は `specs/julia-impl-spec-v2.md` と `specs/julia-impl-spec-v3.md`。本設計書は高位設計として有効だが、実装単位・言語・到達済み範囲はそれらの仕様書を優先する。
- 次に設計書との乖離を縮める実装順は、certified artifact の対象拡張、TRM 長期実験プリセット、四前層高次仕様の一般圏論ライブラリ上での証明、CLI 実験プリセット、可視化 UI の順が妥当である。
