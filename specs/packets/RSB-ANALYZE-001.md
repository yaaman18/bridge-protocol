# RSB-ANALYZE-001: 登録した解析を実行する解析プログラム

- 作成: 2026-10-08（ユーザー指示「どんどん実装を続けて」）
- 出典: 解析計画 v2 草案（`specs/drafts/reactivation-analysis-plan-v2.toml`）の `[interpretation]`・`[incomplete_runs]`・
  `[redundancy]`・`[dc2_unit_informativeness]`・`[decisions]`。RSB-PLAN-002 §5、§6、§14。
- 登録済み profile では run しない。scratch の run と合成した run ディレクトリだけで試験する。

## 1. 目的・解く問題

本番 run の出力（case 記録と判定結果）から、解析計画に書いた結論を計算するプログラムがまだ無い。結果を見た後で
集計の仕方を書けば、事前登録の外で選択の余地が生まれる（RSB-001 の forking paths）。本作業は、解析計画の
各規則をコードにし、run の前に試験で固定する。

## 2. 何を計算するか（解析計画 v2 の規則との対応）

| 段 | 規則（解析計画） | 計算 |
|---|---|---|
| 0. 解析してよいか | stop_conditions、`[incomplete_runs]` | 完了 manifest が `complete`、case の集合が run 開始レコードと一致し重複が無い、各 case に全判定基準の結果があり、結果の欄が `criterion_binding` と一致する。外れれば `not_analyzed`（理由つき）で止まる |
| 1. 撤回条件 | `[decisions].retraction_conditions` | ALL-OFF（q = 0 の case）が DC 真 → run を撤回。DC 真なのに境界が空 → run を撤回（ISOLATED の一貫性）。DC2 真で hSelf・hSMC・hAct のどれかが偽 → DC2 の記録を撤回。DC2 真で beta が空 → DC2 の記録を撤回 |
| 2. 主たる集計 | `primary_tally = "dc_as_defined"` | DC の通過数。DISCRIMINATION（全件通過または 0 件 → 基体 v1 を棄却） |
| 3. 感度読みと頑健性 | `sensitivity_reading = "dc_T"`、`robustness_rule` | dc_T = hSelf_T ∧ hSMC ∧ hAct ∧ hBound の通過数と DISCRIMINATION。dc と dc_T で判定が違えば「冗長性の読みに依存する」 |
| 4. 記述の件数 | `descriptive_counts` | pass / fail_redundancy_ambiguous / fail の内訳、dc 偽で dc_T 真、dc 偽で mask_smc か mask_act が空でない |
| 5. DC2 | `dc2_sigma_cover_cases`、forbidden_adjustments | DC2 の通過数と、そのうち σ 被覆でない case（蝶番の証拠として数えてよいもの）。DC2 真でグラフ境界の hBound が偽の case を並べて記録（誤りとしない） |
| 6. N3 の照合 | `[dc2_unit_informativeness]` | case 記録の単独停止の損失から正解 v4 の対を作り、N3 の対との食い違いを既知の差分の登録簿で分類する。未分類か未決の種類があれば `report_to_user = true` |

数値の閾値はどこにも無い（2026-10-07 の決定で X を廃止）。

## 3. 設計

- 解析は判定基準と同じパッケージ `tools/ReactivationERIEC`（`src/analysis.jl`）に置く。**このパッケージは
  `criterion_binding` で tree OID ごと束縛されるので、解析プログラムも同時に事前登録される。** 解析を直したければ
  再登録が要る。これは意図した性質である。
- 構造（入力・出力ユニット）は登録済み profile から読む。run ディレクトリは case 記録と判定結果だけを持つため。
- 既知の差分の登録簿（`tools/model_audit/fixtures/dc2-known-differences.toml`）は、ユーザーが未決の種類を決めると
  変わりうるので、パッケージの外に置いたまま読み、その SHA-256 を報告に記録する。
- 出力は TOML の報告。同じ入力から同じバイト列になる。

## 4. 仮説・未検証部分

- 正解 v4 と既知の差分の分類を case 記録だけから計算した結果が、監査側の実装（`tools/model_audit/GroundTruth.jl`、回路から
  計算）と一致すること。試験で監査領域の回路について照合する。

## 5. 推奨案と棄却した代案

- 解析を束縛されたパッケージに入れる（推奨）。別パッケージにすると、解析計画 v2 に解析プログラムの束縛を新しく足す必要がある。
- 既知の差分の登録簿をパッケージに入れる案は棄却。未決の種類（損失合成の余分な対）をユーザーが決めたとき、再登録が要ってしまう。
  代わりに SHA-256 を報告に残す。**ただし、これは登録簿が run の後に書き換えられうることを意味する。** 報告に digest が残るので
  事後の監査はできるが、事前登録で縛られてはいない。ユーザー判断事項として報告する。

## 6. ゲート

1. `tools/ReactivationERIEC/test/runtests.jl` に解析の試験を加える:
   - scratch の run（本物の DC・DC2）を解析し、報告の各欄が case ごとの判定結果から独立に数え直した値と一致する。
   - 合成した run ディレクトリで、各停止条件・各撤回条件がそれぞれ発動する。
   - 正解 v4 と既知の差分の分類を case 記録から計算した結果が、監査側の実装と監査領域の回路で一致する。
2. 既存の試験がすべて通る。

## 7. 意味変更の有無

なし。解析計画に書いた規則をコードにするだけで、規則は変えない。

## 8. 禁止変更

登録済みファイルを書き換えない。登録済み profile で run しない。`phenomenal_claim` を動かさない。

## 9. 状態（2026-10-08）

実装とゲートの実行を終えた（`logs/gates/RSB-ANALYZE-001/README.md`）。ReactivationERIEC の依存に SHA・TOML・
SubstrateRegistry を加えた（profile と解析計画を検証して読むため）。
