# G3C clone gate（v2 草案）

状態: G3C v2 runner実装候補。下記の検証ログが必須成功条件をすべて満たす場合に検証済みと扱う。
`specs/loop-orchestration-spec.md` には未反映。

検証証拠（PASS時に有効）: `logs/gates/G3C-v2/G3C-20260904-final-dirty-snapshot.log`

cache隔離監査（PASS時に有効）: `logs/gates/G3C-v2/cache-isolation-20260904-final.log`

## 目的と位置づけ

G3C は、HEAD の byte 束縛を弱めず、かつ本番リポジトリを commit せずに、現在の変更集合へ
単一の `Pkg.test()` を適用する補助ゲートである。G3/G3V の分割実行証拠とは区別する。

G3C v2 が出力する snapshot digest と後続 commit の digest を照合する規則が運用仕様へ確定するまでは、
G3C 単独で `implemented` または `certified` へ status を進めない。commit 後の通常 G3 を主証拠とする。

## 実行

```bash
tools/quiet-test-clone.sh \
  logs/gates/<VP-id>/G3C-$(date +%Y%m%d-%H%M%S).log
```

runner は次を行う。

1. 本番 HEAD、index tree、dirty 状態を記録する。
2. 本番と同じ親ディレクトリに一時sandboxを作り、その中へmain repoとpath依存を兄弟cloneする。
3. tracked change と untracked source を複製する。`logs/**` は原則除外するが、semantic manifest の
   `basis_log` が参照する証拠は契約依存として含める。
4. 一時 clone 内だけで ephemeral commit を作り、commit/tree SHA と test-input digest を記録する。
5. main repoとpath依存の `.lake` を、それぞれclone-localなcopy-on-write copyにする。絶対pathを持つ
   Lake configは破棄し、clone内で再生成させる。本番 `.lake` へのsymlinkは作らない。
6. 一時 clone 内で単一の `Pkg.test()` を実行する。
7. 成否にかかわらず clone とmetadata領域を破棄し、本番 HEAD/index の前後値と破棄結果を記録する。

本番リポジトリでは commit、push、index更新、HEAD更新を行わない。ただし指定されたG3Cログ自体は
本番リポジトリへ書き込む。したがって「本番worktree全体が不変」とは主張しない。

## `.lake` 隔離

- macOS `cp -cR` または GNU `cp --reflink=always` によるcopy-on-writeを優先する。
- copy-on-writeが利用できない場合はfail-closedとする。完全コピーを明示的に許す場合だけ
  `G3C_ALLOW_FULL_LAKE_COPY=true` を指定する。
- main repoまたはpath依存に `.lake` が無い場合はclone-localなfresh cacheを用いる。
- clone-local `.lake` 内のsymlinkが同cache外へ解決される場合は拒否する。
- path依存は一階層上の兄弟Git repoだけを許可し、dirtyな依存はsnapshotの意味が曖昧になるため拒否する。
- main repoとpath依存を同じ一時sandbox内の兄弟として配置し、相対path依存をoriginから切り離す。
- `G3C_LAKE_SHARED_MUTABLE=false` が無いログはv2証拠として扱わない。

`.lake` 全体のsymlinkを用いたv1 runnerはgit状態こそ変更しないが、`lake env lean` のconfig生成や
build出力を本番cacheへ書き込み得るため、ファイルシステム上は完全隔離ではなかった。

## test-input digest

digestはephemeral commitのtree entry（mode、object ID、path）のうち、一般の `logs/**` を除き、
semantic manifestが参照する `basis_log` だけを戻したNUL区切りprojectionを `git hash-object` で
hashした値である。後続commitは同じpolicyで次のように照合できる。

```bash
tools/quiet-test-clone.sh --verify-input-digest <G3C_TEST_INPUT_DIGEST> <commit>
```

digestの表示だけを行う場合:

```bash
tools/quiet-test-clone.sh --print-input-digest <commit>
```

v1ログにはこのdigestが無いため、v1のephemeral snapshotと後続commitの同一性は事後証明できない。

## 必須来歴と成功条件

G3C v2ログは、少なくとも次を同じファイルに持つ。

- ephemeral commit SHA / tree SHA / test-input digest とobject format
- 本番HEAD SHA、実行前後のindex tree、本番dirty状態
- ephemeral commitへ含めた全変更と実行コマンド
- `.lake` copy mode と `G3C_LAKE_SHARED_MUTABLE=false`
- path依存ごとのorigin HEAD/index、cache mode、非共有marker
- tracked patch・対象untracked inventory・対象untracked bytesのcapture安定性
- PASS/FAIL、clone破棄、metadata破棄、本番HEAD/index不変、完了marker

次のすべてがなければ成功証拠として扱わない。

```text
G3C_RESULT=PASS
G3C_CLONE_DESTROYED=true
G3C_METADATA_DESTROYED=true
G3C_ORIGIN_HEAD_OR_INDEX_MUTATED=false
G3C_PATH_DEPENDENCY_HEAD_OR_INDEX_MUTATED=false
G3C_SOURCE_CAPTURE_STABLE=true
G3C_LAKE_SHARED_MUTABLE=false
G3C_END
```

## ledger表記

G3Cを補助証拠として使う間は、通常G3と区別して次のように併記する。

```text
G3: <通常Pkg.test()ログ>; G3C(aux): <clone実行ログ>
```

`G3C: <path>` だけを根拠に status を進めない。

## 旧ログとの関係

- `logs/gates/branch-novelty/G3-temp-commit-20260830.log`: 来歴ヘッダがなく、兄弟配置を保持しなかったため
  `proof-carrying-intersubjectivity` を解決できず失敗した。G3C証拠として不採用。
- `logs/gates/VP-BDY-002/G3-20260901-isolated-committed.log`: 同じく来歴ヘッダがなく、兄弟配置を
  保持しなかったため失敗した。G3C証拠として不採用。
- `logs/gates/VP-BDY-002/G3C-20260901-full-retry1.log`: v1 runnerの全通過履歴として保持するが、
  `.lake` が共有され、test-input digestも無いため補助証拠に限定する。

旧ログは失敗または移行履歴として保持し、再取得しない。

## 将来の昇格条件

G3Cを通常G3の代替へ昇格するには、少なくとも次を別途確定する。

1. v2の隔離条件と必須成功markerを機械検査する。
2. G3C snapshot digestと後続commit digestの一致をstatus遷移前に検査する。
3. ledger更新など実行後にだけ書ける証拠metadataをprojectionへ含めるか除外するかを固定する。
4. `specs/loop-orchestration-spec.md` のG3定義とstatus遷移へ反映し、ユーザーが意味変更を承認する。
