# DC2 有限モデル監査 2026-09-30

対象: `formal-experiments/M1Refinement.lean` の DC2（未批准）。進捗確認
`logs/reviews/finite-model-audit-progress-20260930.md` の推奨1〜4。

## 実行したもの

| ファイル | 内容 |
|---|---|
| `dc2-audit-report.toml` | `julia --project=. bin/eriec-dc2-audit.jl report` の出力（exit 0） |
| `test_dc2_audit.log` | `test/test_dc2_audit.jl`（worker 経由）。12 + 5 + 1 + 69 + 10、すべて通過 |
| `test_countermodel_audit.log` ほか | 件数を更新した既存の監査試験。countermodel 27、implication matrix 8181、assumption suite 64、constraint overlay 72、すべて通過 |
| `mutate_dc2.jl`, `mutation-results.log` | Julia の DC2 判定に変異5件を入れ、直接の量化式との照合が5件すべてを検出 |

## 結果

1. **直接の量化式との照合**: 抽象担体 C={c1,c2,c3}, M={m1,m2}, E={e1} の全 1,048,576 符号化で、
   hSelf2・hSMC・hHingeNeeded・hUnit・Act・beta が一致。Lean 参照模型 M1〜M5 の証明済み事実 14 件と一致。
   NonSingleton を外した参照は不一致を生むこと（比較が空洞でないこと）も試験している。
2. **カタログ**: 述語 `dc2`・`hSelf2`・`hHingeNeeded`・`hUnit`・`beta_nonempty` を追加。
   カタログは 13 → 28 モデル（Lean 参照 5、抽象担体 9、測定回路 1。もう1つの測定証人は既存の
   `p6-dc-only-without_hBound` と同じ回路）。抽象モデルでは、境界を読まない hSelf・hSMC・hAct と、
   κ が全体のときのグラフ境界 hBound（どのグラフでも偽）だけを記録し、他は未観測とする。
3. **含意**: `dc2 → hSelf / hSMC / hAct / beta_nonempty` は Lean 参照・C3・C4 の3文脈で有限反例なし
   （`DC2.toDC` と整合）。C3 の DC2 真 912 通りすべてで、境界を beta とした DC が成立。
   `dc2 → hBound`（グラフ境界）は有限反例あり（m1r-M1, m1r-M5, dc2-c3-dc2-kappa-all）。
   測定由来の3文脈では DC2 が一度も真にならないので、前提未充足。
4. **分離表**: C4・M2・E1 の標本（300万、seed 20260930）で、全条件と単独脱落4型のそれぞれに
   非退化な証人がある。C3 の全列挙では hSelf2 脱落と hHingeNeeded 脱落の非退化な証人は無い（0件）。

## 測定回路での所見（研究判断が必要）

4ユニット全列挙（32,768）と6ユニット系列（20,000）で `hUnit` が真になった回路は 0。
空でない κ が PostFixed2 の回路（2,611 / 734）のすべてで、κ に単独で PostFixed2 になる構成素がある。
DC2 は測定回路で実現されていない。一般に不可能だとは示していない（`general_impossibility = not_established`）。

phenomenal_claim = not_certified。有限の不在を定理に昇格させない。

## 追記: hUnit を MutualPair（N3）に置き換えた後の再実行（同日、ユーザー決定）

決定と撤回条件は `specs/packets/DC2-HUNIT-N3.md`。上の「結果」「測定回路での所見」は置き換え前の記録で、
`dc2-audit-report.toml` と各試験ログは置き換え後の実行で上書きした。

| ファイル | 内容 |
|---|---|
| `lean-M1Refinement-N3.log` | `lake env lean formal-experiments/M1Refinement.lean`（exit 0、エラー 0、公理は3公理の範囲内） |
| `unit-candidates.jl`, `unit-candidates.out` | 候補 N0〜N3 の比較 |
| `gen-dc2-fixture.jl` | 証人 fixture の生成手順 |
| `dc2-audit-report.toml` | N3 での監査レポート |
| `test_dc2_audit.log` | 12 + 5 + 1 + 76 + 10、すべて通過 |
| 既存監査試験ログ | countermodel 27、implication matrix 8181、assumption suite 64、constraint overlay 72、analysis plan 1429+2、model audit 88+24579+32、circuits 8241+16+33、viewer 63、すべて通過 |
| `mutation-results.log` | 変異7件（MutualPair の片方向化・c = d の許容を含む）をすべて検出 |

N3 での結果:
- C3 全列挙: DC2 真 12,105。そのすべてで境界を beta とした DC が成立。
- カタログ 34 モデル（Lean 5、抽象 9、測定 20）。`dc2 → hSelf / hSMC / hAct / beta_nonempty` は6文脈すべてで
  前提充足・有限反例なし。`dc2 → hBound`（グラフ境界）は Lean 参照・C3・測定 P3・測定 P6 二運動の4文脈で有限反例あり。
- 分離表: C4 標本と測定の1入力2運動文脈の両方で、全条件と単独脱落4型に非退化な証人。
- 測定探索（非退化）: 4ユニット全列挙 DC2 656・hUnit だけ偽 114、6ユニット系列 111・9。
