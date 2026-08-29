# failure_mode_review の機械検査 — Stage 2 実装パケット（2026-08-29）

状態: **ユーザー承認済み**（2026-08-29、パケット形式の構造化と下記の範囲縮小を承認）。
codex の提案（agmsg `[AUTO 3/10]` `[AUTO 4/10]`）に対する accept + revised。

## 目的・解く問題

`failure_mode_review` は [specs/verification-practices-v2-draft.md](verification-practices-v2-draft.md) の
P-4 に規則として書かれているだけで、機械検査が一つも無い。規則を書いただけで執行機構が無いものは効かない、
というのが本作業列の出発点であり、この欄はいまその状態にある。前回の「反証条件がゲート欄に落ちていなかった」
と同型の穴なので閉じる。

## 確認済みの証拠

- `specs/verification-failure-modes.toml` の `[[failure_mode]]` は 4 件。
- `tools/mutation_corpus.toml` の `[[mutation]]` は 1 件（`MUT-LEDGER-001`）。
- 既存のパケット文書（`specs/ledger-write-separation-packet.md`、
  `specs/verification-practices-v2-draft.md`）は構造化されておらず、機械可読な review 欄を持たない。
- HEAD = `8ffba0e`、作業ツリーは clean。

## 機械化で得られるものと得られないもの（明示）

得られるのは**参照整合性**だけである。全 ID について記入があるか、未知の ID を書いていないか、
参照先の mutation が実在するか、までは機械が判定できる。

**得られないのは正しさである。**「非該当」と書いたことが真かどうかは機械には判定できない。
全件を非該当と書けば検査は通る。この限界を承知したうえで導入する。緩和として、非該当の場合にも
理由の記載を必須にし、人が後から監査できる状態にする。理由の真偽は機械が見ない。

## 推奨案と棄却した代案

**採用: TOML サイドカー方式。** 散文のパケット（`.md`）はそのまま人が読む文書として残し、
機械可読な部分だけを `specs/packets/<name>.toml` に置く。

- 棄却: markdown の front-matter に埋め込む案。markdown を分割するパーサが要る。
  本リポジトリは TOML 中心であり、既存の読み取り機構をそのまま使えるサイドカーのほうが安い。
- 棄却: 全パケットを 1 ファイルに束ねる案。パケットごとの独立性が失われ、
  差分が交錯する。

**範囲の縮小（codex 提案からの revise）: 該当する失敗様式への mutation ID 要求は今回入れない。**
コーパスの mutation は現在 1 件、レジストリの ID は 4 件である。いま要求すると、作業が止まるか、
止めないために事実と異なる「非該当」が書かれるかのどちらかになる。後者が起きればこの仕組みは
最初から腐る。`mutation_ids` は**任意欄**とし、書かれている場合のみ実在を検査する。

## サイドカーの schema

```toml
schema_version = 1
packet_id = "PKT-PACKET-REVIEW-001"
prose = "specs/packet-review-mechanization-packet.md"

[[failure_mode_review]]
id           = "FM-CALLER-PROOF-BOOL"
applicable   = false
rationale_ja = "本パケットは checker の判定経路に触れず、パケット文書の構造化のみを行うため"

[[failure_mode_review]]
id            = "FM-FALSIFICATION-NOT-GATED"
applicable    = true
rationale_ja  = "review 欄そのものが未ゲートであり、本パケットが対象とする穴に該当する"
mitigation_ja = "負例 fixture により各違反符号が実際に返ることを確認する"
mutation_ids  = []          # 任意。書く場合は corpus に実在すること
```

## 実装対象（この4件のみ）

1. **`tools/verify/packet_review_validation.jl`** — 既存の
   `claim_ledger_validation.jl` と同じ形（`LedgerCheck` 相当の check 列と、
   違反のみを返す関数の二面）で実装する。並行実装を作らない。
2. **`specs/packets/PKT-PACKET-REVIEW-001.toml`** — 本パケット自身のサイドカー。
   自分自身を最初の正例にする。
3. **`test/test_packet_review.jl`** — 正例（`specs/packets/*.toml` 全件が違反ゼロ）と、
   **負例 fixture**（各違反符号を 1 件ずつ発生させる合成サイドカー）。
   fixture は `test/fixtures/packet_review/` に置く。実ファイルを改変しない。
4. **`test/parallel_test_plan.jl`** への登録。

### 検査項目と安定違反符号

- `FM_REVIEW_MISSING_ID` — レジストリにある ID が review に無い
- `FM_REVIEW_UNKNOWN_ID` — レジストリに無い ID が review にある
- `FM_REVIEW_DUPLICATE_ID` — 同一 ID が複数回現れる
- `FM_REVIEW_RATIONALE_MISSING` — `rationale_ja` が欠落または空（該当・非該当を問わず必須）
- `FM_REVIEW_MITIGATION_MISSING` — `applicable = true` なのに `mitigation_ja` が欠落または空
- `FM_REVIEW_UNKNOWN_MUTATION` — `mutation_ids` の要素が corpus に存在しない
- `FM_REVIEW_PROSE_MISSING` — `prose` がリポジトリ相対パスでない、リポジトリ外へ解決される、
  または指すファイルが存在しない

### 固定名

`specs/packets/`、`packet_review_validation.jl`、`failure_mode_review`、
`rationale_ja`、`mitigation_ja`、`mutation_ids`、上記7つの違反符号。改名しない。

## 明示する限界（今回は閉じない）

**散文パケットにサイドカーが存在しないことは検出しない。** 「すべてのパケットが review を持つ」を
機械で保証するには、パケットの網羅的な登録簿が要る。それが無い現状では、validator は
「存在するサイドカーが正しいか」だけを判定する。サイドカーを書かずにパケットを出せば検査は素通りする。
これは P-4 の限界として記録し、本パケットでは閉じない。

既存2件の散文パケットへのサイドカー遡及作成は**要求しない**。

## 反証条件

- 負例 fixture を1件ずつ壊した状態で validator を走らせ、**期待した違反符号だけ**が返ること。
  「何らかの失敗が起きた」では不可。`mutation_check.jl` と同じ厳格さを適用する。
- レジストリに新しい `[[failure_mode]]` を追加したとき、既存サイドカーが
  `FM_REVIEW_MISSING_ID` で落ちること。落ちなければ網羅検査が効いていない。

## 禁止変更

- `specs/verification-failure-modes.toml` の内容変更（本パケットは検査の追加のみ）。
- `tools/mutation_corpus.toml`、`specs/claim-ledger-v2.toml`、`specs/ledger.toml`。
- 既存パケット文書の散文の書き換え。
- `mutation_ids` を必須欄にすること。
- 許容誤差・seed・fixture 値・`phenomenal_claim`・`relation` 系。
- commit / push。

## ゲート

- **G3**: `tools/quiet-test.sh` 経由で `Pkg.test()`。既存の全テストが不変（claim ledger は 861/861）、
  新規 `test_packet_review.jl` が正例・負例ともに通ること。
  ログ `logs/gates/packet-review/G3-<timestamp>.log`。
- **G3V**: 既存の `quiet-verify.sh` は変更しない。今回の対象外。

## 停止条件

- 既存テストの合否が1件でも変わったら、回避策を入れず停止して報告。
- 上記4件以外の変更が必要になったら停止。
- サイドカーの網羅性（未作成の検出）を実装しようとして登録簿が必要になったら停止。今回の範囲外。
