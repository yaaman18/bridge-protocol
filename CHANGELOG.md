# コミット履歴の復元記録

2026-07-11 から 2026-08-30 までの 33 コミットのうち 28 件は、本文が「コミット」または
「commit」だけで作られており、GitHub の履歴からは何をした変更なのか判別できない。
本ファイルはその期間の履歴を、各コミットの差分から復元したものである。

**復元の根拠**: 各コミットが `logs/gates/` 下のどのディレクトリにログを追加したか、
どの Lean モジュール・spec ファイルを新設したか、`specs/ledger.toml` と
`specs/claim-ledger-v2.toml` にどの検証点・contract を追加したか。ゲートログの
ディレクトリ名はどの検証点を扱った作業かを直接示すので、主根拠にしている。

**復元の限界**: これは事後の再構成であって、当時の作業意図の記録ではない。
各エントリの「証拠」欄が指すログとコミット差分が一次資料であり、本文の要約が
それらと食い違う場合は一次資料が正しい。

**この記録の範囲**: 2026-08-30 の `d70dde8` まで。それ以降のコミットは
`.githooks/commit-msg` によって定型語の本文が拒否されるため、コミットメッセージ自体が
説明を担う。本ファイルを継続更新する必要はない。

`(復元)` は本ファイルで再構成したもの、`(原文)` は当時のコミットメッセージそのもの。

---

## 2026-08

### `d70dde8` 2026-08-30 (復元)
**branch novelty を形式化し cert-scope レジストリで164契約を context_local に確定**

`formal/ERIEC/BranchNovelty.lean`、`RefModel/BranchNovelty.lean`、
`RefModel/LossAwareBranch.lean` を新設し `src/branch_novelty.jl` を実装。
`specs/cert-scope-registry.toml` を追加し、全 contract の認証スコープを
`context_local` として登録する（検査された文脈を超えるスコープを主張しない）。

証拠: `logs/gates/branch-novelty/`, `logs/gates/cert-scope/`

### `4d74a14` 2026-08-30 (復元)
**cert-scope 検証を新設し認証スコープの逸脱を検出可能にする**

`tools/verify/cert_scope_validation.jl` と `test/test_cert_scope.jl` を追加。
`final` / `permanent` / `unconditional_cross_context` を陰性 fixture として登録し、
文脈を超える認証主張を拒否する。`specs/structure-repair-order.md` と
`specs/mx-layer-reconsideration.md` を起票。

証拠: `logs/gates/cert-scope/`

### `1dd1e83` 2026-08-29 (復元)
**パケットレビューを機械化し反証条件ドラフト GRP-DYN-5 を起票**

`specs/packet-review-mechanization-packet.md` と `PKT-PACKET-REVIEW-001.toml` を追加。
`tools/verify/packet_review_validation.jl` と 7 件の陰性 fixture で、パケットが
反証条件・緩和策・根拠を欠いたまま受理されることを防ぐ。

証拠: `logs/gates/packet-review/`

### `8ffba0e` 2026-08-27 (復元)
**モデル評価の分離を修正し quiet-build / quiet-test を追加**

`tools/quiet-build.sh` と `tools/quiet-test.sh` を新設し、長いビルド・テスト出力を
ログへ落として要約のみを返すようにする。

証拠: `logs/gates/model-evaluation-artifact/`, `logs/gates/category-pipeline/`

### `eef6b69` 2026-08-27 (原文)
**到達不能になった移行 bootstrap を削除し、空洞化ガードを追加**

### `d795f0b` 2026-08-27 (原文)
**台帳の書き込み権限分離と検証プラクティス v2 を導入**

### `56d39ee` 2026-08-25 (復元)
**チェッカ強化 最終監査: 対象13件を処理し A1/A2 関手契約を再認証**

証拠: `logs/gates/checker-strengthening/`, `logs/gates/A1-STRICT-FUNCTOR-001/`,
`logs/gates/A2-CLOSURE-FUNCTOR-001/`, `logs/gates/VP-REF-001/`, `logs/gates/order-10b/`

### `dfaef4a` 2026-08-23 (復元)
**M4 モデル評価 CLI を新設し VP-OPD-002 / VP-MRK-002 を実装**

`specs/model-evaluation-artifact.md` を起票。`bin/eriec-model-evaluation.jl` と
`src/model_evaluation*.jl` / `src/m4_model_evaluation.jl` を追加し、外部モデルが M4 を
満たすかを判定できるようにする。`Hinge.lean` を更新し `hinge.act` を予約名として登録。

証拠: `logs/gates/VP-OPD-002/`, `VP-MRK-002/`, `VP-GRA-001/`, `VP-HNG-001/`,
`order-10b/`, `order-10c/`, `exact-13-remediation/`, `model-evaluation-artifact/`

### `b6c1088` 2026-08-17 (復元)
**チェッカ強化 第5バッチ: reference_models / wager / worlddc を強化**

`opendynamics.open_graph` を catalog 登録済みとして台帳へ反映。

証拠: `logs/gates/checker-strengthening/`

### `126b099` 2026-08-14 (復元)
**チェッカ強化 第4バッチ: closure / dc / generation を強化**

証拠: `logs/gates/checker-strengthening/`

### `7b9a8f4` 2026-08-14 (復元)
**賭け W6 の有限再帰性を形式化し VP2-WAGER-W6-FINITE-RECURRENCE-001 を追加**

`formal/ERIEC/Wager/Recurrence.lean` を新設し statement を `specs/statements/` へ凍結。
v2 台帳へ claim 1 件を追加。

証拠: `logs/gates/VP2-WAGER-W6-FINITE-RECURRENCE-001/`,
`logs/gates/checker-strengthening/`

### `9fb7e8b` 2026-08-13 (復元)
**チェッカ強化 第3バッチ: generation / graded / reference_models を強化**

証拠: `logs/gates/checker-strengthening/`

### `a0f5d36` 2026-08-08 (復元)
**チェッカ強化 第2バッチ: bridge_functor を強化し感度ケース登録簿を新設**

`test/checker_sensitivity_cases.jl` を追加。強化したチェッカが実際に偽を検出できることを
陰性ケースで確認する。

証拠: `logs/gates/checker-strengthening/`

### `600ef7b` 2026-08-08 (復元)
**チェッカ強化 第1バッチ: layer_composition と viability_closure の自己確認を解消**

同一の内部データから等式の両辺を計算していた検査は定義展開で恒真になる。両者を独立の
経路で構成し直し、分類ラベルを実態に合わせる。

証拠: `logs/gates/checker-strengthening/`, `logs/gates/checker-semantic-manifest/`

### `3a4cc2c` 2026-08-03 (復元)
**checker semantic manifest を新設し checker が実際に判定するものを宣言させる**

`specs/checker-semantic-manifest.toml` を追加。Julia の checker が対応する Lean 命題に
対して持つ関係（`exact_finite_decision` / `witness_validator` / `regression_only` 等）を
契約ごとに明示する。`test/test_checker_semantic_manifest.jl` で整合を検査。

証拠: `logs/gates/checker-semantic-manifest/`, `logs/gates/VP-ADJ-001/`

### `a39f97f` 2026-08-02 (復元)
**coverage 監査 第3段を完了し legacy_coverage 全10件を確定**

`collapse.critical_slowing` / `dynamics.finite_collapse` / `reference_models.v5_1` を追加。
監査結果は、contract が被覆する原子 claim が 7 件、被覆しないものが 85 件。

証拠: `logs/gates/LEDGER-COVERAGE-STAGE3/`, `logs/gates/LEDGER-COVERAGE-FIX/`

### `bf53fa8` 2026-08-02 (復元)
**coverage 監査 第2段: 7 contract を legacy_coverage へ記録**

`world.spectral_band` / `value.endogenous` / `worlddc.no_unconditional_equivalence` /
`invariance.update_bisimulation` / `reference_models.*` の被覆状況を監査。

証拠: `logs/gates/LEDGER-COVERAGE-STAGE2/`

### `306a210` 2026-08-01 (復元)
**PCI アダプタを新設し二軸原則(coverage_audit)を台帳へ導入**

`adapters/ERIECPCI/` を追加し、非退化性・開示・非バンドル性の 3 statement を
`specs/statements/` へ凍結。v1 台帳に `coverage_audit` 軸を追加し、
`test/test_ledger_consistency.jl` で台帳とリポジトリ実体の乖離を検査する。

証拠: `logs/gates/ADP-PCI-INS-001/`, `logs/gates/LEDGER-COVERAGE-STAGE1/`,
`logs/gates/VP2-WDC-BACKWARD-CE-001/`, `logs/gates/VP2-WLD-LAMBDAMAX-001/`

## 2026-07

### `7c805fd` 2026-07-21 (復元)
**Σ1 多様性監査 VP-META-005 と分岐系譜 VP-GEN-006 を実装**

`src/sigma1_diversity_audit.jl` を新設し `MetaSelection.lean` / `LineageWitness.lean` を
追随。`meta.sigma1_diversity_audit` と `generation.branched_rich_lineage_cofinal` を登録。

### `721cc4b` 2026-07-20 (復元)
**VP-GEN-006 / VP-META-005 / VP-RICH-001,002 のゲート証拠ログを追加**

コード変更はなく、実行済みゲートの出力のみを証拠として記録する。

証拠: `logs/gates/VP-GEN-006/`, `VP-META-005/`, `VP-RICH-001/`, `VP-RICH-002/`

### `0354c7c` 2026-07-20 (復元)
**機能終了ライン(VP-TMP-001..005)とΣ1メタ選択(VP-META-001..004)を実装**

`specs/eriec-termination-spec.md` と `specs/eriec-sigma1-experiment-spec.md` /
`eriec-sigma1-run-packet.md` を起票（いずれもユーザー承認済み 2026-07-20）。
`RefModel/CollapseTrace.lean` を新設し `TemporalDC.lean` を拡張。Julia 側に
`temporal_dc.jl` / `sigma_selection.jl` / `sigma1_run.jl` を追加。

証拠: `logs/gates/VP-TMP-00{1..5}/`, `logs/gates/VP-META-00{1..4}/`,
`logs/gates/VP-TMP-META-batch/`

### `d76e20b` 2026-07-20 (復元)
**豊穣系譜の共終性 VP-GEN-005 を形式化・実装し G1-G4 を通す**

`formal/ERIEC/RefModel/LineageWitness.lean` を新設。contract
`generation.rich_lineage_cofinal` を台帳へ登録。

証拠: `logs/gates/VP-GEN-005/`

### `df0fa29` 2026-07-14 (原文)
**Merge pull request #1 from yaaman18/agent/port-v52-from-erie-c**

### `b861a67` 2026-07-14 (原文)
**feat: port v5.2 formalization to bridge protocol**

### `e377896` 2026-07-14 (復元)
**KernelOpen を新設し v5.2 参照モデルの非退化性を統合検証**

`Audit.lean` / `OpenSimC.lean` / `CertifiedArtifact.lean` を追随。

証拠: `logs/gates/VP-V52-REF-NONDEG-INTEGRATED-001/`,
`logs/gates/VP-V52-ANALYTIC-FM4/`, `logs/gates/VP-V52-FORMAL-CORE-001/`

### `5998993` 2026-07-13 (復元)
**生成ラインと解析的 M4 の形式化を進め VP-GEN-002 のゲートを通す**

`Generation.lean` / `Invariance/Spectral.lean` を更新し `src/generation.jl` を追随。

証拠: `logs/gates/VP-GEN-002/`, `logs/gates/VP-V52-ANALYTIC-FM4/`,
`logs/gates/VP-V52-FORMAL-CORE-001/`

### `efff57b` 2026-07-13 (復元)
**v5.2 レビュー修正を certificate catalog へ反映し完了**

証拠: `logs/gates/VP-V52-REVIEW-FIX/`

### `265e388` 2026-07-12 (復元)
**v5.2 参照モデルのレビュー修正を継続し証拠ログを追加**

証拠: `logs/gates/VP-V52-REVIEW-FIX/`

### `8f272b2` 2026-07-12 (復元)
**v5.2 レビュー指摘を受け AnalyticFM4 と RefModelV52 を修正**

証拠: `logs/gates/VP-V52-REVIEW-FIX/`, `logs/gates/VP-V52-FM1-WITNESS/`

### `3119dbb` 2026-07-12 (復元)
**v5.2 マーカー系と解析的 M4 を形式化し16検証点のゲート証拠を追加**

`formal/ERIEC/AnalyticFM4.lean` を新設。`Markers` / `Gate` / `Gap` / `Decay` /
`Centering` / `Value` / `RefModelV52` を v5.2 へ更新し contract test を追随させる。

証拠: `logs/gates/VP-MARKERS-*/`, `logs/gates/VP-V52-*/`（16 ディレクトリ）

### `1622073` 2026-07-11 (復元)
**LICENSE_ERIEC.md を LICENSE.md へ改名し README にライセンス節を追記**

このとき README 内のリンクは `LICENSE_ERIEC.md` のまま残され、以後リンク切れだった。
2026-08-31 の README 改訂で修正。

### `0110274` 2026-07-11 (復元)
**README 3言語を短縮し .gitignore を追加**

冗長な節を削り、英日西の 3 ファイルを同じ構成に揃える。

### `4020388` 2026-07-11 (原文)
**Initial commit: Bridge Protocol v0.1.0**
