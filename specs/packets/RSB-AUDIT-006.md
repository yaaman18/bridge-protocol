# RSB-AUDIT-006 — 二入力の測定モデルをM2背景で探索

2026-09-10、継続探索の第六単位。新規certified VPでも確証実験でもない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、logs/gates/RSB-AUDIT-006/。
直接依存: ModelAudit.AuditCircuit/measure_circuit/check_dc_pattern、BackgroundAudit.check_adjunction_background。
正式API・台帳・対象層・候補・既存閾値は変更しない。

動機: 一入力・M2・非退化背景ではhSelfからhSMC/hActが導かれる。
一入力域でそれらの独立性証人を探索し続けず、Eを二入力にした別contextで探索する。
探索域はN=6とN=7の2つ。E={u1,u2}、M={u_(N-1),u_N}、残り内部。
自己辺なし、Eへの辺はMからのみ。許容辺はsource/destination昇順。
各重みは{-1,0,1}、閾値{1,2}、初期配置は固定LCG系列。
LCGはstate←6364136223846793005*state+1442695040888963407 (UInt64)、
draw(k)=(state>>32) mod k。seed=20260911+N、各20000ケース、途中打切りなし。
P=H=6/L=R=4。全単独介入を再計算し、M2の全N/Xと全DC真偽値を検査。
保存する証人は全介入集合で再測定し、M2、非退化、全4pattern、境界実効性を再検査する。
一般的な不可能性や分布上の頻度を主張せず、全ケース数、背景通過数、発見/未発見を保存。

実行scriptと検証をlogs内に保持する探索単位。テストは保存証人の全再測定と既存checker照合。
既存G1/G2/G4接続は不変。実験の成否でledgerを進めない。

別の明示構成: 二つの独立した入力/出力の帰還対を共通の核とする。
全条件例では支持外へ正負の出力辺を置き、境界に介入差を持たせる。
hSelf分離例は二出力に冗長に支えられる内部ユニットをKへ含め、単独喪失のΦで覆えなくする。
hBound分離例では支持外接続を持たない二帰還対と独立な交互活動を使う。
これらは固定系列の探索で発見したcaseとは区別して、explicit_constructionとして保存する。
P/H/L/R、二入力・二出力、M2、非退化、全4patternを再測定する。
