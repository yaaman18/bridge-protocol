# RSB-001 完了A 実装メモ（2026-09-27）

実装者: Claude（Codex 契約停止中のため、ユーザー指示により臨時に直接実装）。
対象: `specs/packets/RSB-001.md`（改訂3）の完了A（機構実装）。完了B（実ファイルの凍結・登録・push）は未着手。

## 実装したもの

| packet の要求 | 実装 |
|---|---|
| §5 `verify_substrate_registration` / `VerifiedRegistration` | `tools/SubstrateRegistry/src/verify.jl` |
| §3 §4 exact schema（profile / analysis / registry） | `tools/SubstrateRegistry/src/schema.jl` |
| §6 run 開始レコード validator、完了 manifest 雛形 | `tools/SubstrateRegistry/src/records.jl` |
| §7b 順序付き case digest | `tools/SubstrateRegistry/src/cases.jl` |
| §7 固定 remote、一時 bare repo への単発 fetch | `tools/SubstrateRegistry/src/git.jl`, `verify.jl` |
| §8 隔離（最小 Project、subprocess、launcher） | `tools/SubstrateRegistry/Project.toml`, `test/test_substrate_registry.jl`, `bin/eriec-substrate-registry.jl` |
| §9 反証16件 + valid baseline | `tools/SubstrateRegistry/test/runtests.jl` |

`start_run` の実体と run の接続は RSB-002/003 の義務であり、実装していない（§5）。
したがって本単位のゲートは、未来の run API が存在することを証明しない。

## packet が固定していなかったため実装者が決めたこと（ユーザー確認待ち）

以下は完了B で実ファイルを凍結する前に見直すべき判断である。どれも理論の不変条項には触れない。

1. **固定 remote の literal**: `https://github.com/yaaman18/bridge-protocol.git` と `refs/heads/main`。
2. **profile schema（`rsb-profile-schema-v1`）**: `specs/drafts/reactivation-substrate-v1-candidate.toml`
   の節とキーをそのまま採り、`[reporting]` だけを §3 の境界に従って分割した。
   - profile 側に残したもの（何を出力するか）: `[output] record_all_cases`, `[output] phenomenal_claim`。
   - analysis 側へ移したもの（どう読むか）: `zero_pass_count`, `nonempty_flags`, `non_dc_interpretation`, `claim_scope`。
   - キー構成が変わるため、profile の `schema_version` は 3 を要求する（candidate は 2）。
   - §3 が profile 側に置くとした「出力 schema・必須生データ」の具体的な欄はまだ定義していない。RSB-002/003 で
     出力形式が決まった時点で `[output]` を拡張し、validation version を上げる必要がある。
3. **analysis schema（`rsb-analysis-schema-v1`）**: `[interpretation]`, `[incomplete_runs]`（欠落・重複の扱い）,
   `[decisions]`（撤回条件・停止条件・禁止する調整）, `[[falsification]]`（id / condition / expected、1件以上）。
   版キーは profile と衝突しないよう `analysis_schema_version` とした。
4. **共有 identity allowlist**: `profile_id` のみ。値の一致を検査する。
5. **registry schema**: `registry_schema_version = 1` と `[[registration]]` 行。行に
   `registration_commit` は置かない（自己参照、§10）。`author_declared_at_semantics` は
   `self_declared_not_used_for_ordering` 以外を拒否する。
6. **case ID**: `case-<ゼロ埋め整数>`（`case_order = "ascending_integer"` のみ定義）。
   許可文字は ASCII `[a-z0-9][a-z0-9._-]{0,63}`。符号化は `u32be` 長さ前置、件数は `u64be`、
   先頭に `rsb-case-digest-v1` を長さ前置で置く。末尾改行なし。SHA-256。
7. **`weight_sum_bound`**: `weights` と `environment_map` の |w| の総和の上限と解釈した
   （candidate では総和がちょうど 16 = 上限）。一ユニットあたりの上限の意図なら修正が要る。
8. **runner の読み取り**: runner checkout の作業ツリーから両ファイルを読む（clean を要求するので HEAD の blob と一致する）。
   runner ルートの `Manifest.toml` は追跡対象であることを要求する。
9. **§7(5)(iv)**: profile_commit から registration_commit への **ancestry path 上の全 commit**
   （`git rev-list --ancestry-path`）で2つの path の bytes が登録値と一致することを要求する。
   途中で変更して戻した履歴は拒否する。P より前に分岐し2つの path に触れない side branch の merge は受理する
   （side branch 側で path を変えていれば、merge commit 自体が ancestry path 上で変化を持つので拒否される）。
10. **検査順序**（最初に偽になった条件のコードを返す）: remote 観測 → (v) → registry（schema と固定 remote の一致）→ (i)(ii) → (vi) → (iii) → (iv)
    → exact schema → 呼出側期待値 → runner clean → runner bytes。

## 主張の水準（§2 の限定を実装にも適用）

- `VerifiedRegistration` の内部コンストラクタは非公開の witness を要求するが、security boundary ではない。
- テストは固定 remote の代わりに非公開の `_verify` へ bare fixture の URL を渡す。公開 API
  `verify_substrate_registration` は remote を指定するキーワードを持たず、literal の remote だけを使う
  （指定すると `MethodError`。テストで確認）。registry schema も既定で literal の remote 以外の行を拒否する。
- git の system / global 設定を無視して起動し、`ls-remote` と `fetch` はどちらも新規の一時 bare repo の中で
  実行する（`url.<base>.insteadOf` などで固定 remote を差し替えられないようにするため）。
  runner checkout のローカル設定は信頼対象として扱う。
- remote に到達できない場合は `status = UNVERIFIED` とし、成功として扱わない。
- runner の dirty 判定は追跡ファイルの変更と untracked ファイルを見る。ignored ファイルは見ない
  （実リポジトリは `.lake/` や `docs/` を ignore しており、これを含めると常に dirty になるため）。

## 独立レビュー後の修正（2026-09-27、fresh-context 検証エージェントの指摘による）

1. 公開 API が `kwargs...` 経由で固定 remote を上書きできた欠陥を修正（キーワードを明示列挙）。
2. (iv) を ancestry path に限定し、正当な merge の誤拒否を解消。(iv) を直接検査するテストを追加
   （検査を削除するとテストが落ちることを scratch の変異で確認）。
3. 完了 manifest の書き出しを、開始記録と runner 状態からの再計算経由に限定（呼出側の status を使わない）。
   `mismatches` を固定コードに限定。
4. 正規表現の末尾アンカーを `$` から `\z` に変更（末尾改行つき ID・SHA を拒否）。
5. `ls-remote` を一時 bare repo 内で実行。
6. `unit_count` が負のとき `DomainError` ではなく `SchemaViolation` を返すよう修正。
7. 上書きしない書き込みを hardlink による原子的 no-clobber に変更。一時ファイルは必ず削除。
8. テストの抜けを補充: 空の registry（UNREGISTERED）、symlink の拒否、schema 違反の登録、
   registry の未知キー、追跡ファイル変更による dirty、schema 間のキー集合の分離。

## 取り下げの仕組み（2026-09-27 ユーザー決定により凍結前に追加）

- registry schema に `[[withdrawal]]`（registration_id / reason / superseded_by / results_seen_before_withdrawal /
  declared_at / declared_at_semantics）と、登録行の `supersedes` を追加。取り下げは追記のみで、何も削除しない。
- 整合検査: 未知の登録の取り下げ、二重の取り下げ、自分自身を指す superseded_by / supersedes、
  取り下げられていない登録を指す supersedes を拒否する。
- 検証は固定 remote の最新 commit の registry も読む。登録行がそこで変わっていれば `REGISTRY_ROW_EDITED`、
  取り下げられていれば `WITHDRAWN`、registry が消えていれば `REGISTRY_MISSING`。
- `preregistration_strength`: 置き換えの連鎖のどこかに「結果を見た後の取り下げ」があれば
  `post_results_replacement`、なければ `full`。トークンと run 開始レコードへ記録する。
- 解析計画 `[interpretation] post_results_replacement = "not_preregistered_evidence"`。

残る限界: (v) の `_is_ancestor` 検査は、単一 ref の fetch が祖先でない commit を持ち込まないため、
テストでは `_has_commit` だけで同じ結果になる（検査は多重防御として残す）。
