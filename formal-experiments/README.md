# Lean experiments

このディレクトリは探索中、失敗中、または仕様未批准の Lean ファイル専用である。

- `formal/ERIEC.lean` や `formal/ERIEC/**` から import しない。
- `lake build` の default target には含めない。
- 個別確認はリポジトリルートで `lake env lean formal-experiments/<file>.lean` を実行する。
- 本体へ移す前に `sorry` / 独自 `axiom` を除去し、概念モジュールと公開名を確定する。
- statement specification と公理監査は従来どおり `specs/statements/` に置く。
