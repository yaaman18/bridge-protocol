# G3C clone gate（草案）

状態: Claude確認待ち。`specs/loop-orchestration-spec.md` には未反映。

## 目的

G3C は、HEAD の byte 束縛を弱めず、かつ本番リポジトリを commit せずに、現在の変更集合へ
単一の `Pkg.test()` を適用する補助ゲートである。G3/G3V の分割実行証拠とは区別する。

## 実行

```bash
tools/quiet-test-clone.sh \
  logs/gates/<VP-id>/G3C-$(date +%Y%m%d-%H%M%S).log
```

runner は次を行う。

1. 本番 HEAD と dirty 状態を記録する。
2. 本番と同じ親ディレクトリに兄弟クローンを作る。
3. tracked change と untracked sourceを複製する。`logs/**` は原則除外するが、semantic manifestの
   `basis_log` が参照する証拠は契約依存として含める。
4. 一時クローン内だけで ephemeral commit を作る。
5. 本番の `.lake` をクローンへsymlinkし、単一の `Pkg.test()` を実行する。
6. 成否にかかわらずクローンを破棄し、破棄結果をログ末尾へ記録する。

本番リポジトリでは commit、push、index更新、HEAD更新を行わない。一般の `logs/**` は証拠出力として
snapshotから除外するが、semantic manifestが参照する `basis_log` は参照整合性検査の入力なので含める。

## 必須来歴

G3Cログは、ephemeral commit SHA、本番HEAD SHA、本番dirty状態、commitへ含めた全変更、実行コマンド、
PASS/FAIL、クローン破棄結果を同じファイルに持つ。`G3C_RESULT=PASS` と
`G3C_CLONE_DESTROYED=true` の両方がなければ成功証拠として扱わない。

## 旧ログとの関係

- `logs/gates/branch-novelty/G3-temp-commit-20260830.log`: 来歴ヘッダがなく、兄弟配置を保持しなかったため
  `proof-carrying-intersubjectivity` を解決できず失敗した。G3C証拠として不採用。
- `logs/gates/VP-BDY-002/G3-20260901-isolated-committed.log`: 同じく来歴ヘッダがなく、兄弟配置を
  保持しなかったため失敗した。G3C証拠として不採用。

両ログとも失敗の履歴として保持するが、再取得しない。現在の変更集合に対する新しいG3Cログが代替証拠となる。

## 未確定事項

- G3Cを通常G3の代替とするか、HEAD束縛を持つテストがdirty worktreeで阻害された場合だけの補助ゲートとするか。
- ledgerの証拠コメントにG3Cの固定名をどう表記するか。
