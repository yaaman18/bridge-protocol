# Lean 点検 2026-09-30

RSB-003（DC プラグイン）に着手する前の、Lean 側の論理の点検。読み取りと局所実行のみ。
Lean ファイルは変更していない。

## 機械的な検査

| 検査 | 結果 |
|---|---|
| G1 `lake build` | 2813 jobs 成功、error 0。warning 46 件はすべて linter（`simpa`→`simp`、未使用 simp 引数など）。`G1-lake-build.log` |
| `sorry` / `admit` | `formal/` と `formal-experiments/` の 78 ファイル・16827 行で 0 件 |
| `axiom` 宣言 | 0 件 |
| `native_decide` / `implemented_by` / `extern` / `unsafe` / `opaque` | 0 件 |
| 公理依存（本体全体） | ERIEC の全 5238 宣言を走査し、`propext`・`Classical.choice`・`Quot.sound` 以外に依存するものは 0 件 |
| 公理依存（M1Refinement） | 全宣言が上記3公理の範囲内。`DC2.toDC` は `[propext, Classical.choice, Quot.sound]` |
| `formal-experiments/` 4 ファイル | すべて `lake env lean` で通過 |

## 意味の検査で見つかったこと

Lean の証明そのものに誤りは見つからなかった。見つかったのは、**登録済み解析計画 v1
（`specs/reactivation-analysis-plan-v1.toml`、登録 rsb-002 の一部）が Lean の定義・定理を引用する箇所の
誤り2件**である。詳細と訂正は `specs/packets/RSB-PLAN-002.md` §6b。

1. 撤回条件「DC2 が真で DC が偽なら実装誤り（DC2 implies DC）」。`DC2.toDC` が示すのは境界を `beta` と
   した DC への含意で、run で使うグラフ境界の DC への含意ではない。κ = 全ユニットの DC2（`M1.dc2` と同型）
   では、正しい実装でもこの撤回条件が発火する。
2. 反証行 ALL-OFF の期待値「hSelf false」。κ = ∅ なら `hSelf` は空虚に真。2026-09-08 のレビューで
   訂正された誤りが v1 に再び入っていた。

登録 rsb-002 は一度も run していない。

## 確認した整合

- 解析計画 v1 の「σ が行為をすべて覆う case では `HingeNeeded` は自明に成り立つ」は定義と整合する。
  `ρ⋆(κ) ⊆ σ⋆(ε)` なら `Act = ρ⋆(κ)` で、`rhoNH` は κ 内のどの構成素からも行為を取り除くため、
  κ の空でない部分集合は後不動点になれない。
- 反証行 ISOLATED（外向き辺の無い集合で `hBound` 偽）はグラフ境界の定義と整合する。

## 設計上の注記（誤りではない）

本体の `ERIEC.DC` では `boundary` が自由な欄であり、`hBound` は与えた境界と κ が交わることしか
要求しない。境界に κ 自身を与えれば `hBound` は「κ が空でない」とほぼ同じになる。run では基体 profile の
`boundary_rule` が境界を固定するので問題にならないが、Lean の DC 単独では境界の意味は定まらない。
DC2 は関係から導出する `beta` でこれを埋めている。
