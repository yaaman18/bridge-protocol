# G3C clone gate（v2 正式仕様）

状態: **2026-09-05 ユーザー承認により正式G3代替へ昇格。** runnerのPASSだけではstatusを
進めず、commit済みログに対する証拠検証とstatus専用commitの検査を必須とする。
`specs/loop-orchestration-spec.md` §2.1 に反映済み。

検証証拠（PASS時に有効）: `logs/gates/G3C-v2/G3C-20260904-final-dirty-snapshot.log`

cache隔離監査（PASS時に有効）: `logs/gates/G3C-v2/cache-isolation-20260904-final.log`

## 目的と位置づけ

G3C は、HEAD の byte 束縛を弱めず、かつ本番リポジトリを commit せずに、現在の変更集合へ
単一の `Pkg.test()` を適用する補助ゲートである。G3/G3V の分割実行証拠とは区別する。

G3C v2 が出力するsnapshot digestと後続の証拠commitを照合し、さらにその直接の子commitが
対象VPの `bound → implemented` だけを行う場合、通常G3の代替として使用できる。runnerのPASSだけで
`implemented` または `certified` へstatusを進めてはならない。

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

## commit済み証拠の機械検査

証拠検査はworktree上のログではなく、明示した完全commit SHAに格納されたログを読む。

```bash
tools/verify-g3c-evidence.sh evidence \
  logs/gates/<VP-id>/G3C-<timestamp>.log \
  <40桁または64桁のevidence-commit>
```

検査内容は次のとおり。

- 必須marker、単一値field、section境界の一意性と順序
- `G3C_RESULT=PASS`、単一の完全 `Pkg.test()` command、cleanupとorigin不変marker
- logのtest-input digestとevidence commitから再計算したdigestの一致
- commitの`lake-manifest.json`にあるpath依存とlog内の依存集合の一致
- 各path依存のcommit objectが存在し、そのtreeがclean index tree記録と一致
- log pathのrepository内制約と完全commit SHAの強制

path依存の検査ではlogに書かれた絶対`origin`をfilesystem accessへ使用しない。evidence commitの
manifestにある正規な兄弟相対pathだけから検査対象を解決する。

## status遷移 — 2 commit方式

test-input projectionからledgerを除外しない。次の順序を固定する。

1. 対象VPを `status="bound"` のままG3Cを実行する。
2. 実装、テスト、仕様、G3Cログを**evidence commit A**へ保存する。Aではstatusを進めない。
3. 上記 `evidence` commandでAを検証する。
4. Aの直接の子である**status commit B**で、対象VPだけを `bound → implemented` へ進める。
5. 次のcommandでA→Bを検査する。

```bash
tools/verify-g3c-evidence.sh transition \
  <evidence-commit-A> \
  <status-commit-B> \
  <VP-id>
```

Bで変更できるpathは`specs/ledger.toml`だけであり、TOMLとして解釈した内容のうち変更できるfieldは
対象VPの`status`だけである。証拠pathなどのコメント追記は許すが、他の意味fieldは変更できない。
これにより実行後metadataをprojectionから除外する弱化を行わない。

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

正式代替として使う場合は、status commitのコメントにlogとevidence commitを併記する。

```text
G3C: <clone実行ログ>; evidence_commit=<full SHA>
```

`G3C: <path>`だけ、短縮SHA、worktree上の未commitログを根拠にstatusを進めない。
VP-BDY-002では通常G3がすでに主証拠であるため、既存の`G3C(aux)`表記を遡及変更しない。

## 旧ログとの関係

- `logs/gates/branch-novelty/G3-temp-commit-20260830.log`: 来歴ヘッダがなく、兄弟配置を保持しなかったため
  `proof-carrying-intersubjectivity` を解決できず失敗した。G3C証拠として不採用。
- `logs/gates/VP-BDY-002/G3-20260901-isolated-committed.log`: 同じく来歴ヘッダがなく、兄弟配置を
  保持しなかったため失敗した。G3C証拠として不採用。
- `logs/gates/VP-BDY-002/G3C-20260901-full-retry1.log`: v1 runnerの全通過履歴として保持するが、
  `.lake` が共有され、test-input digestも無いため補助証拠に限定する。

旧ログは失敗または移行履歴として保持し、再取得しない。

## 昇格判定（2026-09-05 解決済み）

正式昇格時に次を確定した。

1. v2の隔離条件と必須成功markerを`g3c_evidence_validation.jl`で機械検査する。
2. snapshot digestとevidence commit digestをstatus遷移前に照合する。
3. ledgerをprojectionに残し、2 commit方式で実行後metadataとの循環を解消する。
4. `specs/loop-orchestration-spec.md`のG3定義とstatus遷移へ反映する。

保証する隔離範囲はmain/path依存のsource、Git HEAD/index、`.lake` cacheである。machine-wideな
Julia depotやOS環境までhermeticであるとは主張しない。これは通常G3と共通の実行環境上限である。
