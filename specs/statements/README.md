# ERIEC statement specifications

`claim-ledger-v2.toml` で `spec_status = "frozen"` にする前に、各原子claimの完全なLean型をこのディレクトリへ置く。

## 規則

1. ファイル名は `<VP-id>.lean` とする。
2. binder、typeclass、量化順、仮定、結論を省略しない。
3. 文書にない仮定を追加しない。
4. `[FLD]` はstructureのフィールド型、`[CNJ]` は証明しない `Prop` の型として記述する。
5. 反例は `∃ model, Assumptions model ∧ ¬ Target model` の同一模型形式にする。
6. statement specのレビュー後、正規化した型hashを台帳へ記録する。
7. 実装側の宣言はstatement specと定義的に同じ型でなければならない。

## 初期状態

現在の53 claimはすべて `draft` であり、まだ型は凍結されていない。既存Lean宣言をそのまま正解とみなさず、圏論文書から型を起こしてから既存宣言と比較する。
