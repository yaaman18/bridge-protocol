# RSB-AUDIT-004 — 命題と証拠を伴う比較記録

2026-09-10、継続実装の第四単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、tools/ClaimAudit.jl、
bin/eriec-claim-audit.jl、test/test_claim_audit.jl、test/parallel_test_plan.jl、logs/gates/RSB-AUDIT-004/。
直接依存: 既存ModelAudit.AuditContext/compare_audit_claims/内容digest、Julia標準TOML。
固定tool API: ClaimAudit.AuditClaim、claim_record、parse_claim_record、compare_claim_records。

第一単位のNamedTuple比較は持続化していないため、claim ID、context、命題、真偽申告、理由、
証拠参照をimmutable値として保存する。断定/否定には証拠参照を要求し、未判定は真偽に潰さない。
命題は文字列として比較し、論理的同値・含意を自動推論しない。
内容digestを照合しても真正性や証拠の正しさは認証しない。expected_digestを外部から与えれば内容を固定できる。
比較結果に両方の原文とdigest、全context差分を含め、元の問いや命題を消さない。
同じclaim IDを異なる内容に使った場合は比較を拒否する。残余状態は自動更新しない。
ファイル/TOMLの参照は入力データとして扱い、証拠参照先の取得・実行・外部通信はしない。

禁止変更: formal/、src/、既存catalog/ledger/candidate、数値条件、対象層公理、marker。
対象G3: immutable値・厳格なschema・hash/外部digest・未知値拒否・反対の申告・context差分・
ID再利用拒否・CLIの読み書き。既存G1/G2/G4接続は無変更。
このmoduleはModelAuditを兄弟moduleとして再利用し、既存テスト実行中のModelAudit本体を変更しない。

統合時の追加範囲: test/test_model_audit.jlのinclude guard。
依存理由は、後続ツールとAuditContextの型を共有するため、同一workerでModelAuditを再定義しないこと。
RSB-AUDIT-003の全体G3終了後に適用し、全監査suiteを同じworkerで検査する。
