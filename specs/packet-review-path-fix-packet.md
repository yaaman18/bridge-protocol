# path_is_repo_file の realpath 非対称の修正 — Stage 2 実装パケット（2026-08-29）

状態: **ユーザー承認済み**（2026-08-29、修正の実施を承認）。
claude による独立検証（agmsg `[AUTO 7/10]`）で検出した潜在不具合を閉じる。

## 目的・解く問題

`tools/verify/packet_review_validation.jl` の `path_is_repo_file` が、候補パス側だけを
`realpath` で解決し、リポジトリルート側を解決しないまま `relpath` で比較している。
このため **`project_root` のパスに symlink 成分が含まれると、リポジトリ内に実在する
`prose` が `FM_REVIEW_PROSE_MISSING` で誤って弾かれる**。

検証ツール自身が実行環境によって誤検出するのは、本作業列の目的に反する。

## 確認済みの証拠

```
tools/verify/packet_review_validation.jl:33-36
    resolved = realpath(candidate)          # 候補は解決する
    relative_resolved = relpath(resolved, root)   # root は解決しない
```

再現（claude が実行済み）: 複製ツリーを `mktempdir` で作り、`project_root` を `realpath` せずに
渡すと、`prose` が実在するにもかかわらず違反が
`["FM_REVIEW_MISSING_ID", "FM_REVIEW_PROSE_MISSING"]` となる。`project_root` を `realpath` して
渡すと `["FM_REVIEW_MISSING_ID"]` のみになる。

macOS の `/tmp` は `/private/tmp` への symlink であるため、`/tmp` 配下に checkout すると発現する。
現行の `/Users/yamaguchimitsuyuki/bridge-protocol` は symlink 成分を持たないため実害は出ていない。

## 推奨案と棄却した代案

**採用: 比較の両辺を揃える。** `realpath` した候補は `realpath` したルートと比較する。

- 棄却: 候補側の `realpath` をやめる案。symlink でリポジトリ外へ脱出する経路を検出できなくなり、
  この関数の目的（リポジトリ外への参照を弾く）が失われる。
- 棄却: 呼び出し側に「`project_root` は解決済みで渡すこと」を要求する案。規約を文書に書くだけで
  執行機構が無く、本作業列が閉じようとしている穴と同型になる。

## 実装対象（この2件のみ）

1. **`tools/verify/packet_review_validation.jl`** — `path_is_repo_file` 内で
   ルートも `realpath` で解決し、解決後の比較で両辺を揃える。
   `isfile(candidate)` より前の字句的な `..` 事前検査は現状のまま残す（存在しないパスに
   `realpath` を掛けないため）。
2. **`test/test_packet_review.jl`** — symlink 経由ルートの負例を追加する。
   `mktempdir` で最小ツリー（registry / corpus / prose / サイドカー）を作り、
   そのツリーを指す symlink を別に作り、**symlink 側のパスを `project_root` として**
   validator を呼ぶ。違反ゼロであることを assert する。
   symlink はリポジトリ内に作らない。

## 反証条件（ゲート項目として実行すること）

- 修正前のコードに対して新しい負例を走らせると `FM_REVIEW_PROSE_MISSING` が返ること。
  修正後は違反ゼロになること。両方を確認して初めて、この負例が効いていると言える。
- 既存 7 件の負例は、期待した違反符号**だけ**を返す状態を維持すること。
  症状が消えるかわりに他の検出が緩むことがないのを確認する。
- リポジトリ外への symlink 脱出が依然として弾かれること。
  `prose` がリポジトリ外の実ファイルを指す symlink である場合に `FM_REVIEW_PROSE_MISSING`
  が返ることを負例として確認する。**この確認が無いと、修正が検出力を落としていないと言えない。**

## 固定名

7 つの違反符号、`path_is_repo_file`、`failure_mode_review`、`specs/packets/`。改名しない。

## 禁止変更

- 7 つの違反符号の名称・意味の変更。
- `specs/verification-failure-modes.toml`、`tools/mutation_corpus.toml`、
  `specs/claim-ledger-v2.toml`、`specs/ledger.toml`。
- 既存 7 件の負例 fixture の内容変更。
- リポジトリ内への symlink 作成。
- `project_root` が存在しない場合の防御的処理の追加（呼び出し側の誤りであり、
  起こりえない状況の検証は入れない）。
- commit / push。

## ゲート

- **G3**: `tools/quiet-test.sh` 経由で `Pkg.test()`。
  `test_packet_review.jl` が 13 件から増えて全通過、`claim ledger` は 861/861 のまま不変、
  全体の回帰なし。ログ `logs/gates/packet-review/G3-pathfix-<timestamp>.log`。

## 停止条件

- 既存 7 件の負例のいずれかが、期待符号以外を返すようになったら停止して報告。
- 上記 2 件以外の変更が必要になったら停止。
- リポジトリ外脱出の検出が維持できないと判明したら停止（設計の再検討が要る）。
