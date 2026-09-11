# RSB-AUDIT-004 — 命題比較と元の問いの保持

2026-09-10、claim ID/context/命題/申告/理由/証拠を含むimmutable記録と比較CLIを追加。
`G3-claims-20260910.log` は26/26。TOML改変・不正schema・ID再利用・外部digest・CLIを検査した。
全体G3のbaselineは `../RSB-AUDIT-003/G3-full-20260910.log`。後続の統合検査は
`../RSB-AUDIT-005/G3-audit-integration-20260910.log` に記録する。

`make-context-comparison.jl` から作った `with-initial.toml` と `dynamics-only.toml` は、
同じ回路と候補について「固定候補が存在する」をそれぞれaffirmed/deniedと申告する。
`comparison.toml` では、observationが違うためdifferent_contextとなり、両方の元の記録が残る。
これは一意な選択の存在、内在的な分解の完成、経験所有者の存在を主張していない。

`residual-history.toml` は、元の経験についての問いをopenに保ち、別に登録した機能的な問いを
conditionalとして記録する。機能的な問いの結果で元の問いを消さず、未解決件数は1のまま。
生成確認は `context-comparison.log`。

```bash
julia --project=. bin/eriec-claim-audit.jl compare LEFT.toml RIGHT.toml
julia --project=. bin/eriec-claim-audit.jl check CLAIM.toml EXPECTED_DIGEST
```

申告の真理や証拠の内容は認証しない。証拠参照先からコード実行・通信を起動しない。
digestを自分で再計算できる者への真正性保証ではなく、外部expected_digestを与えた場合に内容を固定する。
比較は正規化されたcontextの値と命題文字列の一致に基づき、論理的同値や含意を推論しない。
