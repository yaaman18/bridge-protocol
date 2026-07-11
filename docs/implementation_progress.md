# ERIE-C 実装進捗ログ

このファイルは、日々の実装進捗・検証結果・仕様との差分を記録する。  
Lean + Julia 構成は現行方針として扱う。Python 風構成の設計文書とは実装言語・配置が異なるが、仕様上の問題とはみなさない。

---

## 2026-06-28

### 実装・仕様

- Lenia action の意味論を本体要件に統一。
  - action は `B_M * a` によるフィールド状態への低ランク身体的介入。
  - kernel/growth parameter は固定法則または外部実験条件であり、action coordinate にしない。
  - `LeniaExperimentConditions` を `LeniaAdapterConfig` の意味論的 alias として追加。
  - `lenia_body_action_contract` / `check_lenia_body_action_contract` を追加。
  - production action 次元 16〜24 と、縮小 prototype / CI profile を区別。
- Lenia adapter config の入力検証を追加。
  - `sigma > 0`, `dt > 0`, `tau_steps >= 1`, `feature_count in (6, 32, 64)`。
- Lenia architecture status / certificate に以下を追加。
  - `action_profile`
  - `action_semantics=:field_intervention`
  - `kernel_parameter_role=:experiment_condition`
  - `action_count`
  - `production_action_dimension`
- 暫定実験受入基準を `ExperimentAcceptanceConfig` として追加。
  - critical slowing threshold: `0.95`
  - eig tolerance: `1e-6`
  - seed: `42`
  - repeats: `3`
  - reproducibility tolerance: `+/-1%`
- `reproducibility_assessment` を追加し、反復 metric の中心値からの最大相対偏差を検査可能にした。
- `run_reproducibility_trials` を追加し、各反復へ固定 seed と replicate index を渡す experiment runner 境界を定義。
- Lenia tau / feature / parameter-grid sweep は既定で各条件を3回実行する。
  - dominant world eigenvalue の最大相対偏差を `+/-1%` で判定。
  - summary、artifact JSON、sweep certificate に seed、反復数、許容差、最大偏差、合否を記録。
  - 全条件の再現性評価が合格しない限り sweep certificate は受理しない。
  - `acceptance_config=nothing` を明示した場合のみ、開発用の単発 sweep とする。
- Lenia report CLI に `--seed` / `--repeats` / `--relative-tolerance` / `--lambda-threshold` を追加。
  - 単一条件 CLI も内部では1要素 sweep として3回実行し、従来の `mode=single` 表示を維持する。
- Lenia 長期実験の運用層を追加。
  - `smoke` / `short` / `long` の `LeniaExperimentPreset` catalog。
  - key-value / TSV 外部 preset と CLI `--preset` / `--preset-file`。
  - 条件ごとの `run-NNN` artifact、JSON/TSV summary、全体 manifest を保存。
  - `--resume` で設定が一致し、必要 artifact が揃った条件だけを再利用。
  - 出力ディレクトリからの sweep report 再構築と欠損 artifact 検出。
  - certified 条件ごとの `certificate.json` と全体 `certificate-graph.json`。
  - CLI `--certified` で Lean 検証済み envelope と certificate graph を生成。
  - `lenia_experiment_plan` で条件番号、条件数、反復を含む実行計画を計算。
  - CLI `--dry-run` で計算前に plan JSON を確認可能。
  - `--run-indices` で安定した `run-NNN` 番号を指定し、長期 sweep を分割実行可能。
  - managed sweep ごとに依存なしの `dashboard.html` を自動生成。
  - Wld dominant eigenvalue、再現性偏差、run状態、artifact欠損を可視化。
  - `collapse_trace_dashboard_html` でWld次元収縮・固有値・critical slowing時系列を可視化。
  - `:zeros` / `:uniform_noise` / `:gaussian_blob` の再現可能なLenia初期条件を追加。
  - 確率反復はローカルRNGへ `seed + replicate - 1` を伝播し、global RNGを変更しない。
  - 初期条件をpreset、外部preset、CLI、resume fingerprint、planへ接続。
  - Lenia run certificateをaggregate `envelope-audit.json` で監査。
  - JSON3 により certified envelope を構文解析し、schema / payload / certificate / trust / kind を構造検査。
  - `observation_series_dashboard_html` で `T` / `V` / `O_hat` / Wld次元の時系列と最新heatmapを生成。
- `specs/generic-sigma-adapter.md` と要件書、Codex/Claude Code 議論記録の Lenia action 定義を更新。
- Phase IV-VII 残存仕様 v4 を実装。
  - `actuated_world` に `:auto` / `:dense` / `:svd` と rank 指定を追加。高次元経路は `T' * T` を実体化せず T の直接 SVD を使い、rank 切り詰めを `WldResult.truncated` で公開。
  - 固定済み Wld 射影への反復到達を `wld_reach_probe` で測定し、`:reached` / `:non_converged` / `:diverged` を返す。
  - 既存の非正規化 `viability_contribution` を維持し、`Measure` と opt-in の `viability_weight_ratio` を追加。カスタム measure は M4 に従い外部 set point を捕捉しないことを呼出側契約とする。
  - schema version 1 の `ObservationArtifact`、system fingerprint、必須 `T` / `V` / `O_hat` / Wld 時系列、Umwelt 射影差、certified envelope、`:not_certified` 灯りガードを追加。
- Stage 1 数値ハードニングを追加。
  - truncated randomized SVD に再直交化付き subspace power iteration を既定2回追加。
  - SVD の oversampling、power iteration 回数、seed を公開し、system pipeline、report、Lenia reproducibility trial まで seed を伝播。
  - `wld_reach_probe` は normalized power iteration の吸引性検査であり物理時間発展ではないことを明記。`target_is_dominant` / `diagnostic` で target 非 dominant を silent divergence と区別。
  - `WorldDCRep` は representation を仮定した条件付き forward として追加。formal-only contract を登録し、既存 Julia bridge certificate には接続しない。
- Stage 2 の実 Lenia artifact 接続を追加。
  - `LeniaArchitectureResult` が schema v1 `ObservationArtifact` を保持し、通常/認証 JSON とファイル出力を最終契約へ切替。
  - kernel、action basis、Lenia 条件、action、初期場から安定した system fingerprint を生成。
  - sweep/CLI は `ObservationArtifactCollection` を出力し、collection と内包 artifact の両方で `phenomenal_claim=:not_certified` を検証。
  - 実 Lenia action 改変で fingerprint と Wld 射影が変わり、artifact 版 Umwelt 相対性が成立する end-to-end テストを追加。
- K2 有限 wireheading guardrail を強化。
  - `hinge_integrity` が self-maintaining / sensory-supported / Act / sensory-only / self-only を分離。
  - `check_K2_strict` は `Act != empty` に加え sensory-only action が空であることを要求。

### テスト・検証

- 追加実装の対象テストを通過。
  - `experiment acceptance`: 18 件。
  - `field coupled system adapter`: 117 件。
  - `Lenia report CLI`: 34 件。
  - `TRM neural experiment CLI`: 40 件。
- Julia 全 1166 テスト通過（214.5 秒）。
  - `Lenia experiment management`: 55 件。
  - `Lenia report CLI`: 57 件。
- plan / 分割実行追加後の対象テスト通過。
  - `Lenia experiment management`: 86 件。
  - `Lenia report CLI`: 74 件。
  - `experiment visualization`: 23 件。
  - `field coupled system adapter`: 130 件。
  - `TRM neural experiment CLI`: 40 件。
- `lake build` 通過。
  - 総 build jobs: 2372。
- Phase IV-VII 残存仕様 v4 実装後、Julia 全 1210 テスト通過（300.1 秒）。
  - `value`: 13 件。
  - `world`: 31 件。
  - `observation artifact v1`: 20 件。
  - Lean ソースは未変更のため、この実装バッチでは `lake build` を省略。
- Stage 1 数値ハードニングと `WorldDCRep` 追加後、Julia 全 1228 テスト通過（354.3 秒）。
  - `world`: 41 件。
  - `system adapter`: 13 件。
  - `Lean Julia contract`: 273 件。
  - `lake build`: 2373 jobs 通過。
- Stage 2 Lenia artifact 接続と K2 finite guardrail 追加後、Julia 全 1264 テスト通過（383.8 秒）。
  - `observation artifact v1`: 32 件。
  - `field coupled system adapter`: 142 件。
  - `Lenia report CLI`: 75 件。
  - `hinge`: 11 件。
  - `checkpoints`: 17 件。
  - Lean ソースは未変更のため、直前の `lake build` 2373 jobs 通過結果を維持。
- Lenia 保存 artifact / certificate / summary の schema・marker・envelope・fingerprint・Wld 数値・SHA-256 監査追加後、`Lenia experiment management` 138 件、`experiment visualization` 28 件、`Lenia report CLI` 75 件、`TRM neural experiment CLI` 40 件通過。
- 公式 TinyRecursiveModels Python bridge 追加後、Julia 全体テスト 1,324 件通過。`ERIEC_TEST_TRM_PYTHON=1` の実Python integration test 10 件も通過。

### 次の作業

1. 長時間 Lenia preset を実データで実行し、性能と容量を計測する。
2. 実データに基づいて高次元 Wld の本番 rank と、production の V measure を決定する。

---

## 2026-06-25

### 実装・仕様

- `specs/julia-impl-spec-v2.md` を現行 Julia 仕様として作成。
  - v1 離散層 + Sensitivity + Value + Body を現行スコープ化。
  - `Wld` 固有値分解と Lenia 実結合は v3 以降へ分離。
- `specs/julia-impl-spec-v3.md` を作成。
  - `Wld = eigenspace(T' * T, λ≈1)` の最小数値層を定義。
- `src/adjunction.jl`
  - 独立 `sigma_rel` 用の `check_galois_conn` を追加。
- `src/dc.jl`
  - `ERIEStructure.hGC::Union{Bool,Nothing}` を追加。
  - `all_M/all_E` 付き smart constructor で Galois connection を検査。
- `src/world.jl` を追加。
  - `WldResult`
  - `world_loop_operator`
  - `actuated_world`
  - `world_nontrivial`
  - `world_projection`
  - `check_umwelt_relative`
- `formal/ERIEC/World.lean` を追加。
  - `worldLoop = T* ∘ T`
  - `WorldFixedVector`
  - `WldNontrivial`
  - `worldLoop_inner`
  - `worldLoop_symmetric`
- `formal/ERIEC/WorldDC.lean` を追加。
  - `DCWorldBridge`
  - `DC` と非零固定方向から `Act` 非空かつ `WldNontrivial` を得る弱形式を証明。
- `formal/ERIEC.lean`
  - `World` / `WorldDC` を import。

### テスト・検証

- `julia --project=. -e 'using Pkg; Pkg.test()'` 通過。
  - `world` テスト 12 件を追加。
  - `body_loop_operator` 直接テストを追加。
  - `ERIEStructure.hGC` 成功/失敗テストを追加。
- `lake build` 通過。
  - `ERIEC.World`
  - `ERIEC.WorldDC`
  - 総 build jobs: 2370

### ドキュメント

- `docs/ERIE_C_requirements.md`
  - 現実装との差分監査を追記。
- `docs/ERIE_C_design_spec.md`
  - Python 風設計と現 Lean + Julia 実装との差分監査を追記。
- `category/tensor_categorical_v5.md`
  - v5 圏論仕様と現 Lean/Julia 実装の対応・未実装点を追記。

### 現在の実装済み核

- Lean:
  - Adjunction
  - Closure
  - Hinge
  - DC
  - Sensitivity
  - Value
  - Body
  - World
  - WorldDC
- Julia:
  - relation
  - adjunction
  - closure
  - hinge
  - dc
  - sensitivity
  - value
  - weighted
  - body
  - world
  - worlddc
  - checkpoints
  - consume
  - observation
  - reachability
  - slowing
  - markers
  - system_adapter
  - toy_systems
  - umwelt
  - experiments
  - policy
  - topology
  - collapse
  - benchmarks
  - reports
  - orderreach
  - graded
  - boundary
  - field_system
  - architecture

### 主要な未実装

- K1 静的検問は実装済み。ただし禁止語は false positive を避けるため `external_setpoint`, `target_pattern`, `ExternalSetPoint` に限定している。加えて `SetPointDiagram` / `terminal_setpoints` / `check_m4_no_terminal_setpoint` を追加し、M4 を「外部 set point 不注入」だけでなく「有限ハーネス上で終対象としての set point を持たない」こととして検査できるようにした。Lean 側にも `SetPointDiagram` / `NoTerminalSetPoint` / `noTerminalSetPoint_forbids_terminal` を追加済み。
- K1 構造検問は `check_K1_structural(response)` として実装済み。禁止語走査だけでなく、`EndogenousBodyResponse` を要求し、通常の `BodyResponse` は内生応答として拒否する。
- `Ô = T ⊙ V` の最小 Julia 実装は `weighted_sensitivity` / `viability_weights` として実装済み。
- `WorldDC` の弱形式に対応する Julia テストは実装済み。
- `consume` 相当の最小インターフェースと `MinimalPolicy` は実装済み。
- TRM topology catalog は `topology_catalog` として実装済み。
- 四参照系ベンチマークの最小ハーネスは `run_reference_benchmarks` として実装済み。
- `Wld` 到達可能性と critical slowing down、FM-1〜4、盲視アナログ分類は数値層の最小実装済み。
- 観測構造レポートは `observation_structure_report` として実装済み。
- `Wld ∩ ↑ε(σ)` の有限順序・到達方向版は `ordered_reachable_world_projection` として実装済み。
- 階付き動態の最小核（`ψ_step`, `graded_step`, `graded_trace`, `w_crit`）は実装済み。
- 吸収補集合と境界射の最小核は `absorbing_complement` / `boundary_edges` として実装済み。
- Lenia に差し替え可能な場結合アダプタ核は `field_system_adapter` として実装済み。ただし本格 Lenia の成長関数・カーネル設計ではない。
- `direction_map` は `DirectionMap` として実装済み。`ε(σ)` を環境結合側に残し、`direction_map(e)` で到達可能作動方向へ写す二段解釈を採用。
- `DCWorldBridge` は強い同値証明ではなく、`worlddc_bridge_claim() == :consistency_harness` として整合ハーネス扱いを明示。Lean 側コメントにも反映済み。
- Lenia 最小 adapter は `LeniaFieldSystem` / `lenia_system_adapter` として実装済み。標準 Gaussian growth、デフォルト 1 step。
- critical slowing の暫定閾値は `CriticalSlowingConfig` と `critical_slowing_assessment` として config 化済み。
- 観測構造の最小 artifact は `observation_artifact` / `observation_artifact_json` として実装済み。
- Lenia adapter は `default_lenia_system` で k=16 作動基底、n=32 特徴量まで接続済み。`lenia_gaussian_kernel`, `lenia_action_basis`, `lenia_features` を追加。
- `feature_direction_map` で感受性テンソルの feature 行から到達可能作動方向を生成できるようにした。
- 観測 artifact は単発だけでなく `observation_series_artifact_json` と `write_observation_series_artifact` で時系列 JSON ファイル出力まで接続済み。
- `normalized_system_adapter` を追加し、基準 action の `T' * T` 最大固有値を 1 に合わせることで、Lenia 系から `observation_structure_report` / `DCWorldBridge` / artifact まで直通する統合経路を確認済み。
- 階付き thin category / presheaf law の最小核を Julia (`FiniteThinCategory`, `GradedPresheaf`, `FourPresheafSystem`) と Lean (`formal/ERIEC/Graded.lean`) に追加。
- 四前層の高次仕様は、自然変換 (`PresheafNaturalTransformation`, `FourPresheafTransformation`)、階層間 relation family (`PresheafRelationFamily`)、タグ付き遷移余積 (`TransitionCoproduct`) の有限 harness まで Julia/Lean に追加済み。Lean 側では `TransitionInputSum` / `TransitionOutputSum` を `Sigma` 型として定義し、`transitionInputCopair_unique` / `transitionOutputCopair_unique` により copair の一意性まで証明済み。さらに `PresheafTransitionCoproduct` / `presheafTransition_naturality` と Julia 側 `PresheafTransitionCoproduct` を追加し、前層 fiber 上の遷移が制限写像と可換であることを検査できる。Lean 側では fiberwise output copair の一意性も `PresheafTransitionOutputSum` / `presheafTransitionOutputCopair_unique` として追加済み。
- TRM topology は `TRMProgram` / `TRMConsumer` / `run_trm_program` により、`SystemPipelineResult` 互換 payload から Action を返す consume loop に接続済み。
- TRM closed rollout は `TRMClosedRolloutStep` / `TRMClosedRolloutResult` / `run_trm_closed_rollout` として実装済み。`TRMConsumer` が返した feedback action を `advance_system_adapter` で次 step の field / Lenia 状態へ戻す。Lenia では各 step の観測 pipeline を `normalize_pipeline=true` で再正規化し、状態遷移自体は生の adapter に適用する。
- TRM 学習対象・損失関数・rollout dataset は `TRMRolloutSample` / `TRMRolloutDataset` / `TRMLossWeights` として実装済み。closed rollout から `trm_rollout_dataset` で教師 action 付き sample を生成し、`trm_dataset_loss` で予測器または予測列に対する action MSE と world/reachability/slowing 補助項を評価できる。
- TRM 学習ループの最小更新器として `TRMLinearActionModel` / `fit_trm_linear_action_model` / `trm_predict_action` / `trm_linear_training_step` を追加。rollout dataset の観測特徴から ridge pseudo-inverse で action model を fitting し、baseline loss、model loss、改善量、受理判定を `TRMTrainingStepResult` として返す。さらに依存追加なしの自作小規模 tanh ネット `TRMNeuralActionModel` / `fit_trm_neural_action_model` / `trm_neural_training_step` / `trm_neural_training_run` を追加し、rollout dataset から action model を勾配降下で fitting し、checkpointed run として継続学習できる。`TRMNeuralOptimizerState` / `trm_neural_optimizer_state_json` / `write_trm_neural_optimizer_state` により最終 model weights と loss/epoch trace を外部保存できる。`write_trm_neural_optimizer_state_tsv` / `read_trm_neural_optimizer_state_tsv` により依存なしの復元用 TSV checkpoint も保存・読込できる。`trm_neural_optimizer_checkpoint_certificate` / `certified_trm_neural_optimizer_checkpoint` により TSV checkpoint artifact 自体も certificate envelope に接続済み。`run_trm_neural_training_experiment` により closed rollout、dataset 化、checkpointed neural training、optimizer state、summary/output directory 保存、任意の certified JSON 出力までを backend preset として実行できる。`run_trm_neural_training_experiment_sweep` により hidden dim / learning rate / checkpoint count / epoch 条件の複数 run と sweep summary 出力もでき、`resume=true` 時は各 run directory の `run-summary.tsv` を読んで同条件の完了済み run を再利用する。`continue_from_optimizer=true` 時は `optimizer-state.tsv` から model weights / loss trace / epoch trace を復元し、不足 checkpoint だけ追加学習する。`trm_neural_experiment_sweep_report` / `write_trm_neural_experiment_sweep_report` により、sweep 返り値または保存済み output directory から best run、完了 run 数、欠落 artifact を集約した監査レポートを生成できる。`trm_neural_experiment_sweep_report_certificate` / `certified_trm_neural_experiment_sweep_report` により aggregate report も certificate envelope に接続済み。`trm_neural_experiment_sweep_certificate_graph` により各 run の certified artifact ファイルと report certificate の存在を graph として集約でき、`trm_neural_experiment_sweep_certified_envelope_audit` / `certified_json_artifact_audit` により各 envelope JSON の必須構造を逆引き監査できる。`trm_neural_experiment_preset_catalog` / `trm_neural_experiment_preset` により `:smoke`, `:short`, `:long` の長期実験 preset catalog も追加済みで、`read_trm_neural_experiment_preset` により key=value / TSV 外部presetも読み込める。`trm_neural_experiment_preset_certificate` / `certified_trm_neural_experiment_preset` により preset schema も certificate envelope に接続済み。neural model は `activation=:tanh` を構造体と certificate に明示し、`epochs >= 1` を要求する。
- Lenia n=64 特徴量を `lenia_features(...; n=64)` として追加。
- Lenia report runner 層を `run_lenia_architecture` / `compare_lenia_tau_steps` / `compare_lenia_feature_counts` / `compare_lenia_parameter_grid` として追加。τ step 比較、feature count sweep、tau×feature 複合 grid sweep、artifact JSON 生成まで実行可能。
- Lenia report artifact CLI runner は `run_lenia_report_cli` と `bin/eriec-lenia-report.jl` として実装済み。通常の単発/tau/parameter-grid artifact に加え、`--preset`, `--preset-file`, `--resume`, `--certified`, `--dry-run`, `--run-indices` による長期 sweep の計画・分割実行が可能。TRM neural experiment CLI runner は `run_trm_neural_experiment_cli` と `bin/eriec-trm-neural-experiment.jl` として実装済み。`--preset smoke|short|long`, `--preset-file`, `--system toy|lenia`, `--hidden-dims`, `--learning-rates`, `--checkpoint-counts`, `--epochs-per-checkpoint`, `--output-dir`, `--resume`, `--continue`, `--certified` 等を指定し、単一 run または複数条件 sweep の summary / report / run artifact / certified checkpoint artifact を生成できる。
- Lenia 長期 sweep の保存済み `artifact.json` は `lenia_observation_artifact_audit` で `ObservationArtifactCollection` schema、JSON 構造、外側・内側の `phenomenal_claim=:not_certified`、certified envelope を再検査する。run ごとの `certificate.json` も schema / trust boundary / payload kind を再検査する。欠落と不正を別集計し、不正 artifact / certificate は resume 完了条件から除外する。
- managed Lenia run は system fingerprint を summary JSON/TSV に保存し、resume 時に collection が artifact 1件であることと fingerprint 一致を検査する。別条件の構造的に正しい artifact への置換も `artifact_invalid` として拒否する。
- summary の `dominant_eigenvalue` は artifact 内の最新 Wld eigenvalues から再計算して照合し、summary TSV だけの数値改ざんも resume 完了条件から除外する。
- `lenia_experiment_summary_audit` で summary JSON と resume 基準の summary TSV を全運用フィールドについて照合し、片方だけの欠損・改ざんを検出する。
- artifact JSON 本文の SHA-256 を summary JSON/TSV に保存して照合し、同一 system fingerprint の tensor 内容破損や artifact 取り違えも検出する。
- Lean-Julia contract test を `test/test_formal_julia_contract.jl` として追加。`formal/ERIEC.lean` の import、各 Lean モジュールの代表定義・定理、対応する Julia export/API の存在を機械的に検査する。
- certified artifact / Lean checker 境界を `formal/ERIEC/CertifiedArtifact.lean` と `src/certification.jl` として追加。Lean 側で typecheck 済み contract catalog を `lake env lean --run formal/ERIEC/CertifiedArtifact.lean` から TSV 出力し、Julia 側で宣言種別、formal entry import、export/API、checker symbol を検査する。`lean_certified_artifact` / `verify_lean_certified_artifact` で正式 catalog を Julia から取得・検証できる。検査済み manifest は `certified_artifact_envelope` で実行時 artifact に添付可能で、envelope は `schema_version=1` と `trust.boundary=:lean_core_julia_shell` を持つ。payload が catalog 未登録の Lean contract id を参照した場合は拒否する。観測 artifact については `certified_observation_artifact_json` / `write_certified_observation_artifact` / `write_certified_observation_series_artifact` まで接続済み。
- `adjunction.system` の Julia checker として `check_erie_structure` を追加。`ERIEStructure.hGC` が false の場合は拒否し、有限台 `all_M` / `all_E` が与えられた場合は `check_galois_conn` で Galois connection を再検査する。Lean catalog の `juliaChecker` も `check_erie_structure` に更新済み。
- concrete instance certificate として `dc_world_bridge_certificate` / `certified_dc_world_bridge`、`presheaf_transition_certificate` / `certified_presheaf_transition_coproduct`、`no_terminal_setpoint_certificate` / `certified_no_terminal_setpoint`、`trm_rollout_dataset_certificate` / `certified_trm_rollout_dataset`、`trm_linear_action_model_certificate` / `certified_trm_linear_action_model`、`trm_training_step_certificate` / `certified_trm_training_step`、`trm_neural_action_model_certificate` / `certified_trm_neural_action_model`、`trm_neural_training_step_certificate` / `certified_trm_neural_training_step`、`trm_neural_training_run_certificate` / `certified_trm_neural_training_run`、`trm_neural_optimizer_state_certificate` / `certified_trm_neural_optimizer_state`、`trm_neural_optimizer_checkpoint_certificate` / `certified_trm_neural_optimizer_checkpoint`、`lenia_architecture_status_certificate` / `certified_lenia_architecture_status`、`lenia_tau_sweep_certificate` / `certified_lenia_tau_sweep`、`lenia_feature_sweep_certificate` / `certified_lenia_feature_sweep`、`lenia_parameter_grid_certificate` / `certified_lenia_parameter_grid` を追加。`DCWorldBridge` は整合ハーネスであること、前層遷移余積は fiber membership・自然性・fiberwise copair 一意性 contract に接続されること、NoTerminalSetPoint は求めの図式が終対象 set point を持たないことを Lean contract に接続する。TRM rollout dataset は sample 数・action 次元・重み・world/reachability/classification metadata を certificate payload に入れる。TRM 線形 action model は feature/action 次元、ridge、training/recomputed loss を certificate payload に入れる。TRM training step は baseline loss、model loss、改善量、予測次元検査、受理判定を certificate payload に入れる。TRM neural action model は feature/hidden/action 次元、activation、learning rate、epoch、training/recomputed loss を certificate payload に入れる。TRM neural training step は neural fitting checker、activation、loss 改善、予測次元検査を certificate payload に入れる。TRM neural training run は checkpoint 数、累積 epoch、checkpoint loss、最終 loss を certificate payload に入れる。TRM neural optimizer state/checkpoint は最終 model weights、loss/epoch trace、monotone epoch、final loss consistency、TSV roundtrip boundary を certificate payload に入れる。Lenia architecture status は world 非自明性、DCWorld harness、到達性、critical slowing、classification を certificate payload に入れる。Lenia tau/feature/parameter-grid sweep は sweep 対象、projection distance、dominant eigenvalue、slowing warning、status codes を certificate payload に入れる。`run_lenia_architecture` / `compare_lenia_tau_steps` / `compare_lenia_feature_counts` / `compare_lenia_parameter_grid` は `certificate_check` を受け取り、指定時は certified observation artifact JSON を返す。
- `certificate_dependency_graph` / `certified_dependency_graph_json` を追加。各 concrete certificate payload から Lean contract id、Lean module/declaration 依存、Julia checker、数値仮定、trust profile を抽出し、`payload_kind -> contract/checker` と `contract -> Lean declaration` の依存 edge として機械的に取得できる。
- `DCWorldHarnessResult` / `dc_world_harness` を追加し、追加仮定を明示した整合ハーネスとして `DCWorldBridge` を検査可能にした。`assumptions_used` により、受理判定が `:dc_result`, `:wld_nontrivial`, `:nonzero_fixed_direction`、必要時は `:ordered_reachability` に依存することを返す。
- `LeniaArchitectureResult` を検証結果として強化。`harness`, `reachability`, `slowing_assessment`, `status` を持ち、`Wld ∩ ↑ε(σ)`、DCWorld 整合、slowing warning、classification を一体で返す。
- `LeniaArchitectureStatus` を `architecture_ok` / `architecture_warn` / `architecture_reject` / `architecture_error` の 4 値として追加。現 runner の判定規約は、harness rejected なら `architecture_reject`、harness accepted かつ reachable かつ slowing warning なしなら `architecture_ok`、harness accepted だが reachability 不成立または slowing warning ありなら `architecture_warn`。`architecture_error` は実行例外を上位 runner/CLI で包むための予約値。
- `compare_lenia_tau_steps` は projection distance、dominant eigenvalue、slowing warning、classification、harness accepted、reachable、status code を summary として返す。
- Samsung SAIL Montreal の公式 TinyRecursiveModels を `external/TinyRecursiveModels` に clone し、commit `c01103738605ba39d1430519b1ee0c62f4c707f8` で動作確認した。Intel macOS では公式 CUDA 依存をそのまま導入できないため、`.venv-trm` の PyTorch CPU 環境と JSON subprocess bridge (`python/trm_bridge/bridge.py`, `src/trm_python_bridge.jl`) を追加した。公式 `TinyRecursiveReasoningModel_ACTV1` の health check、初期化 smoke inference、ローカル checkpoint inference を Julia から実行できる。公式学習処理は NVIDIA/CUDA 環境が別途必要。
- 完全な `DC ⇔ Wld 非自明`。
- certified artifact と Julia 数値実装の意味論同値。現在は Lean contract catalog と Julia checker/API 境界の検査まで。
- 四前層高次仕様の一般圏論ライブラリ上での普遍性証明。現在は軽量 `Sigma` 型表現での copair 一意性まで。
- 本格 Lenia 場の追加実験設定（`P_E` n=64 特徴、長期 τ step 比較、大規模 sweep 管理）。
- TRM 長期実験 preset の拡張。`trm_neural_experiment_preset_catalog` による `:smoke`, `:short`, `:long` preset、`read_trm_neural_experiment_preset` による外部preset、preset certificate、`run_trm_neural_training_experiment` による closed rollout から checkpointed neural training と output directory 保存までの backend preset、`run_trm_neural_training_experiment_sweep` による複数条件 sweep、`resume=true` による完了済み run 再利用、`continue_from_optimizer=true` / CLI `--continue` による optimizer checkpoint からの追加学習、sweep aggregate report/certificate/certificate graph/envelope audit は実装済み。
- 三層テンソルの実可視化 UI。JSON artifact は実装済み。

### 次の推奨作業

1. certified artifact の対象を Lenia 長期 sweep / TRM 長期実験プリセットへ広げる。観測 artifact、`DCWorldBridge`、前層遷移、TRM rollout dataset、TRM 線形 action model、TRM training step、TRM neural action model、TRM neural training step、TRM neural training run、TRM neural optimizer state/checkpoint、Lenia architecture status、Lenia tau/feature/parameter-grid sweep envelope は実装済み。
2. TRM neural training experiment の preset / report 管理を堅牢化する。現状は built-in `:smoke`, `:short`, `:long` preset、key=value / TSV 外部 preset、preset schema certificate、sweep aggregate report certificate、certificate graph、certified envelope 逆引き監査、`run-summary.tsv` による同条件 run 再利用、`optimizer-state.tsv` による model weight 継続復元、checkpoint certificate envelope まで実装済み。次は envelope JSON の完全パース監査を追加する。
3. 四前層高次仕様の Lean 証明面を、軽量 `Sigma` 型表現から一般圏論ライブラリ上の普遍性定理へ拡張する。
4. 本格 Lenia 場の追加実験設定（長期 tau step 比較、大規模 sweep 管理）を追加する。
5. CLI runner の実験プリセットを拡張する。Lenia report CLI と TRM neural experiment CLI、built-in preset catalog、external preset file、preset certificate、resume / continuation / certified checkpoint 出力、実験結果集約レポート/certificate/graph/audit は実装済み。次は certified envelope JSON の完全パース監査を追加する。
