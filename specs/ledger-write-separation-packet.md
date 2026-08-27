# 台帳の書き込み権限分離 — Stage 2 実装パケット（2026-08-25）

ユーザー承認: 本日、第一段と第二段の実装を Codex へ依頼することを明示的に承認。
第三段（`checker_relation` / `certification_status` / `certification_log` / `contract_id` の
`[[audit]]` テーブルへの分離）と `specs/ledger.toml`（v1）の扱いは**本パケットの範囲外**。

## 目的・解く問題

`specs/claim-ledger-v2.toml` では、主張の内容（構造側が所有）と認証の判定（監査側が所有）が
同一エントリに同居しており、主張文を書き換えても既存テストが一つも落ちない。
証明できた内容に合わせて主張文の方を弱めるドリフトが検出されない。
本パケットは、権限管理ではなくハッシュ照合によって、この分離を機械的に強制する。

## 確認済みの証拠

- `test/test_claim_ledger.jl:33-37` は `statement_spec` が指す Lean ファイルの sha256 を再計算し
  `statement_hash` と照合する。保護対象は **Lean の主張文だけ**。
- 同ファイル 40-49 行は、`proof_status = "unproved"` に `claim_kind = "conjecture"` と
  `checker_relation = "observation_only"` を強制し、`contract_id` を持つ claim に
  `certification_status = "certified"`、`CertifiedArtifact.lean` の catalog 行、
  `certification_log` の実在を強制する。証拠なしの認証はすでに不可能。
- TOML 内の `statement_ja` と `conclusion` はハッシュ対象外であり、無保護。
- `specs/claim-ledger-v2.toml` の実測値: `[[claim]]` 91 件、`spec_status = "frozen"` 86 件、
  `"draft"` 4 件（残り 1 件は `[defaults]` の draft）、`contract_id` 38 件。
  `statement_ja` / `conclusion` / `statement_spec` は 91 件すべてに存在する。
- 反証条件に相当する欄は、v1・v2 いずれの台帳にも存在しない。

## 仮説・未検証部分

- 91 件すべてについて、現行の `statement_ja` と `conclusion` が現行の認証と整合しているという前提で
  `certified_text_hash` の初期値を `claim_text_hash` と同値に置く。個別の内容監査は行わない。
  この初期化は「今この時点の文言に対して認証が下りている」という記録であり、遡及的な正当化ではない。

## 推奨案と棄却した代案

採用: `claim_text_hash`（構造側）と `certified_text_hash`（監査側）の二欄を置き、
認証済み claim では両者の一致をテストで要求する。主張文を変えると両者が食い違い、
認証を回復するには監査側が新しい `certification_log` とともに `certified_text_hash` を
更新するほかない。

棄却: 単一の `claim_text_hash` のみを置く案。文言とハッシュを同時に更新すれば通ってしまい、
偶発的なドリフトしか捕まえられない。権限分離の効果が出ない。

棄却: ファイル分割（`ledger-claims.toml` / `ledger-audit.toml`）。
`test/test_claim_ledger.jl`、`test/test_ledger_consistency.jl`、`tools/CategoryPipeline.jl`、
`src/model_evaluation.jl` の読み出し箇所すべてに波及する。第三段として保留。

## 反証条件

- 第一段: 主張文を書き換えたうえで `claim_text_hash` を更新した認証済み claim について、
  テストが落ちないなら、`certified_text_hash` の照合が実装されていないか無効化されている。
  受け入れ検査として、実際に 1 件の文言を書き換えて落ちることを確認し、変更を戻すこと。
- 第二段: `falsification_ja` を全件 `"未記入"` にしたまま `falsification_pending_max` を
  下げずに新規 claim を追加できるなら、ラチェットが効いていない。

## 意味変更の有無

無し。欄の追加と検査の追加のみで、既存欄の意味、判定の意味、公開 API、真実源の配置は変更しない。
`relation` の昇格・降格を一切含まない。

## 実装パケット

### 対象

`specs/claim-ledger-v2.toml` と `test/test_claim_ledger.jl` のみ。

### 第一段: 主張文のハッシュ保護

1. 全 91 件の `[[claim]]` に `claim_text_hash` を追加する。値は
   `"sha256:" * bytes2hex(sha256(codeunits(statement_ja * "\n" * conclusion)))`。
   TOML デコード後の文字列をそのまま連結し、正規化・トリムは行わない。末尾改行を付けない。
2. `contract_id` を持つ 38 件に `certified_text_hash` を追加し、初期値は同 claim の
   `claim_text_hash` と同値にする。
3. `test/test_claim_ledger.jl` の `for claim in claims` ループに次を追加する。
   - `claim_text_hash` が存在し、再計算値と一致すること（全件・無条件）。
   - `contract_id` を持つ claim は `certified_text_hash` を持ち、
     `claim_text_hash` と一致すること。
4. 既存の `statement_spec` / `statement_hash` の検査は変更しない。

### 第二段: 反証条件の欄とラチェット

5. 全 91 件に `falsification_ja` を追加し、値は**全件とも文字列 `"未記入"`** とする。
6. ファイル冒頭（`[defaults]` の後、最初の `[[claim_group]]` の前）に次を追加する。

   ```toml
   [migration]
   falsification_pending_max = 91
   ```

7. `test/test_claim_ledger.jl` に次を追加する。
   - 全 claim が `falsification_ja` を持ち、`strip` 後が非空であること。
   - `falsification_ja == "未記入"` の件数が `falsification_pending_max` 以下であること。
   - `falsification_pending_max <= 91` であること。
8. `spec_status == "frozen"` に対する非プレースホルダ要求は**まだ追加しない**。
   86 件が即座に落ちる。この要求はラチェットが 0 に到達した後の別パケットで追加する。

### 固定名

`claim_text_hash`、`certified_text_hash`、`falsification_ja`、
`[migration]`、`falsification_pending_max`。改名しない。

### 禁止変更

- `specs/ledger.toml`（v1）に触れない。
- 既存の `statement_ja`、`conclusion`、`statement_spec`、`statement_hash` の値を変更しない。
- `specs/statements/*.lean` に触れない。
- `falsification_ja` に実質的な反証条件を書かない。全件 `"未記入"` のままとする。
  反証条件の起草は構造側（claude）の作業であり、本パケットの範囲外。
- 許容誤差、seed、fixture、`phenomenal_claim` を変更しない。
- 既存メソッド・既存欄の意味を変えない。追加のみ。
- `relation` / `checker_relation` / `certification_status` を変更しない。
- commit・push しない。

### ゲート

- G3: `Pkg.test()`。`test/test_claim_ledger.jl` と `test/test_ledger_consistency.jl` の通過に加え、
  全体の回帰がないこと。`tools/quiet-test.sh` を使い、全文ログを
  `logs/gates/ledger-separation/G3-20260825.log` に保存し、要約のみ返すこと。
- 受け入れ検査: 認証済み claim を 1 件選び `statement_ja` を書き換えて
  `test_claim_ledger.jl` が落ちることを確認し、確認後に変更を戻す。
  この確認の出力も同ログに含めること。

### 停止条件

- 既存テストが落ちる場合、回避策を入れずに停止して報告する。
- `claim_text_hash` の付与中に、`statement_ja` または `conclusion` を持たない claim が
  見つかった場合は停止して報告する（実測では 0 件のはず）。
- 欄の追加以外の変更が必要になった場合は停止して報告する。
