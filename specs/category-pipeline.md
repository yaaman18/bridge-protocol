# 圏論更新パイプライン

`category/三層構造の圏論的定式化_v5_1.md` の節ハッシュを基準とし、変更節から
`specs/category-impact.toml` の直接VP、さらに `specs/ledger.toml` の依存閉包を求める。
その結果から更新対象の Lean 宣言、Julia API、テストを
`specs/category-impact-report.md` に出力する。
G1 は変更節に対応する Lean モジュールだけを `lake build ERIEC.<Module> ...` で
増分ビルドする。

圏論仕様とその作業メモは `category/` を正規の配置先とする。新しい圏論文書を
`docs/` へ生成してはならない。`docs/` は一般説明、議論記録、実装文書に限定する。

## コマンド

```bash
# 初回だけ。現在の圏論文書をレビュー済み基準として登録する
julia --project=. bin/eriec-category-pipeline.jl baseline

# 変更検出と更新対象レポート生成（ファイル監視からもこれを呼ぶ）
julia --project=. bin/eriec-category-pipeline.jl impact

# 基準を動かさず G1〜G4 を実行する
julia --project=. bin/eriec-category-pipeline.jl check

# 全ゲート成功時だけ節ハッシュ基準を更新する
julia --project=. bin/eriec-category-pipeline.jl accept
```

`baseline` は基準ファイルが存在する場合には拒否される。通常の更新で基準を進められるのは
`accept` だけである。ゲート出力は `logs/category-pipeline/` に保存する。

## 停止条件

- 変更節の `vp_ids` が空: 新しい圏論的主張として扱い、claude による台帳起票まで停止する。
- 全体規律の節だけは `all_vps=true` とし、全VPへ影響を伝播する。空の対応を黙って許可しない。
- 節削除、未知VP、依存循環、存在しないテスト: 構成不整合として停止する。
- G1 `lake build`、G2 Lean↔Julia contract、影響テスト、G4 certificate のいずれかが失敗:
  基準を更新せず停止する。

このパイプラインが自動化するのは変更影響の特定と検証であり、数学からLean/Juliaコードを
無検証生成することではない。コード更新は台帳の `owner` が行い、証明・契約・テストの成功が
受理条件になる。

## 常駐監視

`fswatch` が利用できる環境では次を起動する。

```bash
scripts/watch-category-pipeline.sh
```

監視は `category/` 以下の圏論文書・台帳・Lean・Julia・テストの変更ごとに
`check` を再実行し、未受理の変更節に対応する増分ゲートだけを通す。新しい正規圏論文書を追加した場合は、同時に
`specs/category-impact.toml` の追跡対象へ反映する。
