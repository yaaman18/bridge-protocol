# RSB-002 実装メモ（2026-09-27）

実装者: Claude（Codex 契約停止中のため、ユーザー指示により臨時に直接実装）。
対象: `specs/packets/RSB-002.md`。R1〜R3 はいずれも推奨案（ユーザー決定 2026-09-27）。

## 実装したもの

| 項目 | 実装 |
|---|---|
| 測定エンジン（design-r2 §2〜§6） | `tools/ReactivationMeasurement/src/{substrate,measure}.jl` |
| case 記録の出力 schema（packet §5） | `tools/ReactivationMeasurement/src/records.jl`（`rsb-case-record-v1`） |
| `start_run(token::VerifiedRegistration; runner_repo, run_id, out_dir)` | `tools/ReactivationMeasurement/src/run.jl` |
| profile schema v2（出力 schema を profile digest の対象にする） | `tools/SubstrateRegistry/src/schema.jl` ほか。v1 の登録は引き続き v1 として検証する |
| 隔離 | 依存は SHA・TOML・SubstrateRegistry のみ。root のテストは subprocess 起動のみ |
| 出し直す profile | `specs/reactivation-substrate-v1-r2.toml`（substrate〜enumeration は凍結 v1 と同一 bytes） |

## 実装者が決めたこと

1. **関係はすべてのユニットについて記録する。** design-r2 §7 の台は M = O、E = I だが、測定記録は
   全ユニットの π/ρ/α/σ を持ち、台への制限は RSB-003 の reader が行う（情報を捨てない側に倒した）。
2. **集合の表現**: ユニット index を LSB とする bit マスク（profile の `bit_order` と同じ）。
3. **`start_run` の出力先**は runner checkout の外に限る（中に書くと runner が dirty になり、
   完了照合が `runner_dirty` で失敗するため）。
4. **case 記録は case ごとに1ファイル**（`cases/case-NNN.toml`）。開始レコードと完了 manifest は
   SubstrateRegistry の関数で書く。
5. **出し直しの profile_id は `reactivation-substrate-v1` のまま**とした。基体の数値は同一で、
   解析計画 `reactivation-analysis-plan-v1.toml`（凍結済み bytes）をそのまま組み合わせられるため。
   登録 ID で区別する。

## 変異テスト（packet §9 の完了条件）

作業用フォルダのコピーで検査を一つずつ壊し、隔離スイートが落ちることを確認した。
ログ: `logs/gates/RSB-002/mutation-20260927.log`

| 壊した検査 | 失敗したテスト数 |
|---|---|
| NO-FORCING（停止した元ユニットを off に固定） | 782 |
| RHO-PI（ρ を別の試行から計算） | 12 |
| MINIMALITY（直下の部分集合だけと比較） | 1 |
| SAME-BRANCH（分岐を z の次の状態から開始） | 136 |
| 出力 schema の照合を削除 | 1 |
| NO-WRITEBACK（準備 trace に発信停止を混入） | 704 |

MINIMALITY を検出したのは非単調な喪失表の専用 fixture だけで、符号つきランダム回路との照合
（12 回路）では検出されなかった。検出はされるが、網は薄い。

## 実行していないこと

- 凍結 profile（v1 / v1-r2）での測定は一度も行っていない（R1）。`substrate_from_profile` による
  基体の構築と schema 照合だけを行った。
- DC・DC2・境界の評価は RSB-003。
