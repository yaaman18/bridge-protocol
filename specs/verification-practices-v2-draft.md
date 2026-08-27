# 検証プラクティス v2 — 確定版（2026-08-27）

状態: **ユーザー承認済み**。本日、ドラフトの改訂と実装指示の発行が承認された。
本文書は claude の原案（2026-08-27 初版）に対する codex の feasibility 監査
（agmsg `[AUTO 5/10]` `[AUTO 6/10]` `[AUTO 8/10]`）を反映した確定版である。
初版の設計は複数箇所で棄却された。棄却理由も併記する。

## 目的・解く問題

今セッションで確認された失敗様式は三つ。

1. パケットに反証条件が書かれていたのに、実行されるのはゲート欄だけだった（弱い受け入れ検査）。
2. パケット作成者が同じパケットの検証を行った（自己検証）。
3. 同型の設計誤り（caller 供給の proof Bool / 不透明 callback の受理）が P1・P5・R-A で3回反復した。

「監査を第三の agent へ出す」案は、費用・判定品質・再現性の理由で不採用。
代わりに、判定を人格から**決定的な手続き**へ移す。

---

## P-1. 敵対入力は temp copy に与える（live worktree を改変しない）

### 初版の棄却

初版は「実ファイルをバックアップ → 改変 → テスト実行 → 復元 → sha256 照合」だった。**棄却。**
SIGKILL・電源断・並行編集で作業ツリーが壊れる。`git stash` による代替も、ユーザーの
dirty/untracked な作業を巻き込むため不採用。

### 確定設計

**(a) 検証ロジックを path-injectable な validator へ切り出す。**

```
tools/verify/claim_ledger_validation.jl
  任意の台帳パスを受け取り、安定した違反コードの列を返す。
  例: CERTIFIED_TEXT_HASH_MISMATCH / CLAIM_TEXT_HASH_MISMATCH /
      FALSIFICATION_MISSING / STATEMENT_HASH_MISMATCH
```

通常テスト（`test/test_claim_ledger.jl`）と mutation runner は**同一の validator を使う**。
並行実装を作らない。

**(b) mutation コーパスは、検出されねばならない改変の一覧である。**

```
tools/mutation_corpus.toml
  [[mutation]]
  id            = "MUT-LEDGER-001"
  target        = "specs/claim-ledger-v2.toml"
  edit          = { find = "...", replace = "..." }   # 決定的なテキスト置換
  expect_code   = "CERTIFIED_TEXT_HASH_MISMATCH"      # 単なる非0でなく、この符号
  author        = "claude"                            # P-2 の証拠欄
  rationale_ja  = "certified_text_hash 据え置きの文言改変は検出されねばならない"
```

**(c) runner は実ファイルに触れない。**

```
tools/verify/mutation_check.jl
  1. 事前 baseline: 実ファイルに対し validator が違反ゼロ（PASS）であることを確認。
  2. 対象を tempdir へコピー。
  3. find が対象内で一意に一致することを確認（複数一致・不一致なら失敗）。
  4. コピーにのみ改変を適用。
  5. コピーに validator を実行し、expect_code が返ることを assert。
     「何らかの失敗が起きた」では不可。期待した符号でなければ失敗扱い。
  6. 実ファイルの SHA-256 が手順を通じて不変であることを確認。
  1件でも「検出されるべきなのに検出されなかった」があれば非0で終了。
```

SIGKILL されても live tree は汚れない。journal も lock も復旧手順も不要になる。

**(d) 実行位置は独立サブゲート `G3V`。**

`Pkg.test()` に混ぜない。`tools/quiet-verify.sh` を用意し、
`logs/gates/<batch>/G3V-<timestamp>.log` へ create-only で保存する。

**(e) 初件は `MUT-LEDGER-001` のみ。** 汎用の mutation 基盤を先に作らない。安定後に
proof Bool / callback / 循環オラクルへ拡張する。

**費用**: 「一定」ではなく「1 件あたり一定」。コーパス件数に線形。

---

## P-2. 負例の交差著作

各保護機構の mutation コーパスには、**その機構を実装しなかった側が書いた改変を最低1件**含める。
実装者は自分が防いだ穴しか突かない。今回、実装者（codex）の受け入れ検査は弱い改変のみで、
本来の歯にあたる強い改変は非実装者（claude）が追加した。この偶然を規則にする。

著者は `author` 欄に記録する。ただし **`author` は証拠であって権限境界ではない**。
この欄がアクセス制御として機能すると読んではならない。

---

## P-3. 検証は再実行可能な成果物として残す

段5 の独立検証は、散文の主張でなく**リポジトリ内の再実行可能スクリプト**として残す。

- 置き場所は `tools/verify/`。既存の checker-semantic-manifest / 台帳整合テスト /
  category パイプラインの明示走査対象とは干渉しない（codex 監査で確認済み）。
- agmsg では散文でなく、スクリプトのパスと実行出力を引用する。
- **ゲートから実行する。** 呼ばれないスクリプトは腐る。

---

## P-4. 失敗様式レジストリ（安定 ID）

### 初版の棄却

初版は「procedure log を真実源とし、パケットのチェックリストに転記」だった。**棄却。**
procedure log は追記型で肥大し、真実源に向かない。

### 確定設計

```
specs/verification-failure-modes.toml
  [[failure_mode]]
  id          = "FM-CALLER-PROOF-BOOL"
  title_ja    = "caller が供給した proof Bool を検査器が受理する"
  evidence    = "logs/gates/checker-strengthening/order-11-stage1-audit-20260815.log"
  ...
```

- 真実源は本ファイル。**procedure log は発見経緯の証拠**として残すが、参照先にはしない。
- パケットは ID を参照する。転記しない。
- パケットに必須欄 `failure_mode_review` を置き、各 ID について
  適用性（該当 / 非該当）、該当時の緩和策、対応する mutation ID を記録する。

初期登録は、今セッションで実際に観測されたものに限る。

---

## P-5. ラチェットの単調性

### 初版と第二案の棄却

初版（`pending <= max` と `max <= 91` のみ）は**棄却**。過去値から `max` を再増加させる変更を
検出できない。ラチェットにラチェットが無かった。

第二案（`Pkg.test()` 内から git 履歴を読む）も**棄却**。通常テストがリポジトリ・履歴・
ブランチ状態に依存して hermetic でなくなる。配布物や shallow clone で成立しない。
さらに、コミット済みで作業ツリーが綺麗な場合は基準が自己参照になり、常に通って何も検査しない。

### 確定設計

```
tools/verify/ratchet_check.jl --base-ref <commit>
  git show <base>:specs/claim-ledger-v2.toml から base の pending_max を取得し、
  working tree の pending_max と比較して current <= base を要求する。
  解決された base の SHA をログへ必須記録する。
```

- `--base-ref` は**呼び出し側が明示する**。自動推測して certified PASS を出さない。
- git や base-ref が使えない場合、内容整合は通常テストで PASS とし、
  単調性は **UNVERIFIED として別枠**に出す。緑にしない。完全 PASS を名乗らない。
- 実行位置は `Pkg.test()` ではなく **G3V**。
- 将来 CI を追加する場合は、同じ G3V コマンドを呼ぶだけでよい。

**事実確認**: 本リポジトリに CI は存在しない。`.github/workflows`、`.gitlab-ci.yml`、
`.circleci`、`Makefile` のいずれも無い。git remote（`origin`）は存在するが workflow 定義は無い。

---

## 未解決項目（後の解決とする）

**単調性は通常のテスト実行では一度も検査されない。** P-5 は G3V を明示的に走らせたときにだけ
効く。`Pkg.test()` を通しただけでは、ラチェット上限の引き上げは検出されない。
ユーザー判断により、本項は本パケットの範囲外とし、後の解決項目として記録する。
解決の候補は、ゲート実行の習慣化、pre-commit hook、将来の CI 導入。

---

## 反証条件

- **P-1**: mutation コーパスが全 green のまま、コーパス外の改変による検出漏れが再発したら、
  コーパス追加では追いつかない証拠であり、そのとき初めて第三の手を再検討する。
- **P-1(c)**: runner 実行の前後で対象ファイルの SHA-256 が変化したら、temp copy 設計が
  破れている。
- **P-4**: 必須欄を導入した後も同型の設計誤りが反復したら、チェックリストは形骸化しており、
  パケット linter の機械化が要る。
- **P-5**: `--base-ref` を明示したにもかかわらず `max` の引き上げが検出されないなら、
  base の解決が誤っている。

## 意味変更の有無

無し。判定の意味・公開 API・理論不変条項・relation の強さに触れない。
ただし `failure_mode_review` をパケット必須欄にすることは**手順の変更**であり、
procedure log の改訂として別途ユーザーの確認を要する。本文書の実装範囲には含めない。
