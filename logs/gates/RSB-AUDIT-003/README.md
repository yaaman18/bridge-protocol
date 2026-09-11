# RSB-AUDIT-003 — 対称性と観測制限

2026-09-10、回路から自己同型を列挙し、支持候補がその作用で閉じていることと固定候補を検査する。
固定候補が一つでも、候補クラス自体は外部から与えており、内在的分解の十分条件ではない。

## 個別検証

- `G1-20260910.log`: 既存Lean全体2813 jobsをビルド。
- `Lean-measured-persistence.log`: 実験Leanの測定上の必要条件3補題を個別検査（exit 0）。
- `Lean-equivariant-choice-retry.log`: 実験Leanの選択不能補題を個別検査（exit 0）。
- `G3-symmetry-20260910.log`: 対称性・初期状態・候補閉性・全状態/全介入の可換性・CLI、533/533。
- `G3-full-20260910.log`: 測定・対称性suiteを含むPkg.test()がexit 0で通過。
- `symmetry-examples.toml` / `symmetry-examples.log`: 回路と候補を含む再現例。
- 既存G2/G4 bindingに変更なし。実験Leanは本体import/default targetに追加していない。

失敗した初回 `Lean-equivariant-choice.log` は保持。importなしのファイルでType*を使ったため、
5行目に `unexpected token '}'; expected term`。Lean標準の明示的宇宙変数と証明項に直して通過した。

## どこまで分かったか

同じ配線の二つのe↔m回路で、候補を左右の支持集合とする。
両方の初期状態が同じなら回路全体の交換対称性があり、一つの支持候補を不変には選べない。
片方だけonの初期状態を含めると対称性は破れるが、今度は二つとも固定候補として残る。
初期状態を比較対象から外せば交換対称性が戻る。
結果の違いはcontextの違いであり、「同じ問いの答えが矛盾した」とは扱わない。

Leanの選択不能補題は、対象を固定する操作が選択肢には固定点を持たないなら、
その操作と可換な選択関数は存在しないという条件付きの命題。
Juliaの一般的な自己同型列挙器全体をLeanで検証したという主張ではない。

測定側では、π(m)=Q\Q_mである限り全π像がQに入り、Φ(K)もQ内に収まる。
したがってhSelf: K⊆Φ(K)にはK⊆Qが必要。KにQ外の要素が一つでもあればhSelfは不成立。
これは測定の表現範囲を明らかにする結果であり、理論全体の説明不可能性ではない。
phenomenal_claim=not_certifiedを維持し、対象層・certified API・台帳は変更しない。
