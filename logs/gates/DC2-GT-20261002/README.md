# DC2 hUnit（N3）の正解照合 2026-10-02

仕様: `specs/packets/DC2-GROUND-TRUTH-001.md`。正解の型とラベル: `tools/model_audit/fixtures/organization-ground-truth.toml`。

## 実行したもの

| ファイル | 内容 |
|---|---|
| `freeze.txt` | N3 を型に適用する前に記録した、fixture と仕様書の SHA-256 |
| `ground-truth-report.toml` | `julia --project=. bin/eriec-dc2-audit.jl ground-truth`（exit 0）。fixture の digest は freeze と一致 |
| `test_dc2_ground_truth.log` | 2 + 11 + 1、すべて通過 |
| `test_model_audit.log`, `test_test_plan.log`, `test_dc2_audit.log` | ModelAudit に GroundTruth.jl を加えた後の再実行 |

## 結果（15型、各3通りの並び順）

- 設計の整合: 15型すべてで、測定した持続集合が設計どおり。並び順を変えても結果は不変。
- **偽陽性 0、誤った対 0**（健全性）。
- 一致: 組織あり9型、組織なし3型。
- **偽陰性 3**: `loop2-no-motor-detached`, `loop2-no-motor-motor-follower`（運動ユニットを含まない閉路）、
  `redundant-hub`（ハブが2つの閉路のどちらからでも持続できる）。
- **対の取りこぼし 5 / 埋め込み閉路 15**: 上の3型の閉路4つと、`two-loops-one-way` の閉路 c↔d
  （c が b からも十分な入力を受けるので、d を止めても c が失われない）。
  この指標は初回実行の後に追加した。凍結したラベルは変えていない。
- 旧 hUnit（IrredUnit ∧ NonSingleton）は組織あり12型すべてを取りこぼす。

## 解釈（推論、ユーザー判断待ち）

1. 運動ユニットを含まない閉路: DC2 の産出は行為（M）を介するので、N3 は定義上これを組織と見ない。G は理論中立に
   置いたので食い違う。N3 の欠陥か、ERIE-C の前提の帰結かはユーザーが決める。
2. 十分な供給源が2つある閉路: 単独の発信停止では依存が見えない（DC の冗長性への盲目と同じ仕組み）。
   π・ρ を複数同時停止から作れば見える可能性があるが、それは測定プロトコルの変更（N3-RETRACT-PROTOCOL）にあたる。

phenomenal_claim = not_certified。照合の相手は設計上の正解で、現実の系ではない。
