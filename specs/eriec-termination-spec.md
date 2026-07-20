# ERIE-C 機能終了スペック（functional termination line）

起票 2026-07-20（ユーザー承認済み）。TemporalDC（内生時間上の DC 認証）の上に、
**全体系 DC の喪失遷移（機能終了）とその永続性・排他性**を形式化する。

## 目的関数（本ライン全体の設計方針・ユーザー決定 2026-07-20）

**外部公理を追加しない限り、機能終了を構造的に外せないことの明示**（反セルフハック・セーフガード）。

- 不死（機能終了の内部回避）の内部構成は、M1 違反（precariousness の喪失）∧ M4b 違反
  （永続保証状態 = 到達可能終対象）の二重偽Cであり、Mod(M1〜M4) の**外**。
- 逃げ道を作る唯一の手段はメタ層からの公理注入であり、それは個体への write-back を要するため
  Σ-purity 違反として必ず可視化される。
- 非導出性の証明手段は RefModel 方式: 「全系可死」の無矛盾モデルが実在すれば
  「内部脱出」は対象理論の定理ではない（VP-TMP-005）。

## 命名規律（形式層で「死」を使わない）

- Lean 宣言・台帳 claim・contract_id は「機能終了 (functional termination)」「DC 喪失」で表記する。
- 「死」は docs/メモ側の解釈ラベルに限る。灯り条項（`phenomenal_claim = :not_certified`）により
  「灯りが消えた」ことは決して certify されない。生の側で灯りを主張しないのと対称。

## 対象範囲の固定（codex 提案 (1) への回答）

本ラインの対象は**単一 TRM の `GeneratedTrace` 上の全体系 DC 認証**（`Certification`）。
部分死・局所損傷との排他は個体性の《系 S, 分解 D》2軸判定との接続を要するため
**後続 VP として予約**し、本バッチには含めない（可視ギャップとして明示）。

## 論理的前提（証明済み・利用する既存資産）

- `ERIEC.TemporalDC.FunctionalTerminationStep`（[TemporalDC.lean:157](../formal/ERIEC/TemporalDC.lean#L157)）:
  `T.next x y ∧ C.dcHolds x ∧ ¬ C.dcHolds y` — 機能終了ステップの既存定義。
- `ERIEC.TemporalDC.Certification.resumes_not_terminated`（同 175）: 休止→再開は機能終了と両立しない（単段）。
- `ERIEC.Decay.iterate_upd_dec_empty_absorbing`（[Decay.lean:185](../formal/ERIEC/Decay.lean#L185)）:
  κ = ∅ は崩壊力学の吸収状態。
- `ERIEC.Decay.abstract_collapse`（同 200、v5.2 §22.4）: 崩壊仮定（d1/d4・R2'・sig2）下で
  有限ステップ内に κ = ∅ へ到達し以後永続。
- `ERIEC.DC` の `hBound : (kappa s ∩ boundary).Nonempty`（[DC.lean:18](../formal/ERIEC/DC.lean#L18)）:
  κ 空の構成を認証する DC certificate は存在し得ない（不可逆性接続の鍵）。

---

### VP-TMP-001 — 認証観測層（DC 実喪失と観測欠損の区別）

`dcHolds : Occurrence → Prop` 単一述語では「DC が実際に喪失した」と「認証観測が欠けている」を
区別できない。`ActionObservation` と同型の read-only 観測構造を認証層に追加し、
機能終了の主張を**観測された生起の上に限定**する。

予約する Lean 宣言（namespace `ERIEC.TemporalDC`、既存ファイル `formal/ERIEC/TemporalDC.lean` へ追記）:

```
/-- 認証層の read-only 観測痕跡（ActionObservation の認証層版）。-/
structure CertificationObservation {A : OpenSystem.{u}}
    (T : GeneratedTrace.{u, v} A) where
  observed : T.Occurrence → Prop

/-- 両端点が観測されている機能終了ステップのみを「観測された機能終了」と呼ぶ。-/
def Certification.ObservedTerminationStep {A : OpenSystem.{u}}
    {T : GeneratedTrace.{u, v} A} (C : Certification T)
    (O : CertificationObservation T) (x y : T.Occurrence) : Prop :=
  C.FunctionalTerminationStep x y ∧ O.observed x ∧ O.observed y

/-- 観測欠損: この生起については終了とも生存とも主張しない。-/
def CertificationObservation.GapAt {A : OpenSystem.{u}}
    {T : GeneratedTrace.{u, v} A} (O : CertificationObservation T)
    (x : T.Occurrence) : Prop := ¬ O.observed x

theorem Certification.observedTermination_is_termination : （観測された終了 → 機能終了）
theorem Certification.observedTermination_not_gap : （観測された終了の両端点は観測欠損でない）
```

Julia 側: `check_observed_termination(trace, obs_mask)` — 有限 trace と観測マスクに対し、
観測欠損の生起で終了主張が立たないことを検査。

### VP-TMP-002 — 永続機能終了（分類子）と排他性・未生との区別

永続性は**定理として導出不可能**（現構造は再認証を妨げない）ため、**定義に組み込む**。
「全ての機能終了は不可逆」を主張しない — 可逆な DC 喪失（臨界動揺）と不可逆な喪失を
語彙として分離し、不可逆性の証明義務を witness 側（VP-TMP-003）へ移す。

予約する Lean 宣言（namespace `ERIEC.TemporalDC`、同ファイルへ追記）:

```
/-- 永続機能終了: 終了ステップ以後、到達可能ないかなる生起も再認証されない。-/
def Certification.PermanentTerminationStep {A : OpenSystem.{u}}
    {T : GeneratedTrace.{u, v} A} (C : Certification T)
    (x y : T.Occurrence) : Prop :=
  C.FunctionalTerminationStep x y ∧
    ∀ z, Reachable T.next y z → ¬ C.dcHolds z

/-- 未生: いかなる生起も認証されたことがない。-/
def Certification.NeverCertified {A : OpenSystem.{u}}
    {T : GeneratedTrace.{u, v} A} (C : Certification T) : Prop :=
  ∀ x, ¬ C.dcHolds x

theorem Certification.permanent_no_resume :
  （永続終了後に到達可能な任意の z から、いかなる ResumesAlong も成立しない。
   証明核: ResumesAlong は OperationalPauseAt z すなわち dcHolds z を要求し、
   永続性の ∀z ¬dcHolds z と矛盾）
theorem Certification.permanentTermination_not_neverCertified :
  （永続終了の存在は未生と両立しない。証明核: 終了ステップは dcHolds x を要求）
```

Julia 側: `check_permanent_termination_prefix(trace, horizon)` — 地平線 H 内の非回復のみ検査。
**永続性は ∀-未来主張なので有限計算では反証可能・検証不能** — 無限主張は Lean のみが払う
（arbitrarily_large 系・VP-GEN-005 cofinality と同じ分界）。

### VP-TMP-003 — 崩壊参照 trace（TemporalDC–Decay 接続・不可逆性の構造的証人）

不可逆性の構造的担保の中心証明義務。崩壊力学 `upd_dec` の反復を `GeneratedTrace` に載せ、
永続機能終了の具体証人を構成する。

構成の設計（正確な型は codex が G0 で凍結。**universe は具体証人につき u=0 明示を推奨** —
VP-GEN-005 G1 の universe 不整合の教訓）:

- Occurrence = ℕ、state n = `upd_dec^[n] c0`、next n (n+1)。OpenSystem の step は upd_dec 像。
- `dcHolds n` := 状態 n の構成を認証する適合 DC の存在（∃ 形。G0 で固定）。
- 鍵補題: `∀ dc : DC M E C S, (dc.kappa dc.s).Nonempty`（hBound から自明）—
  κ = ∅ の構成には certificate が存在し得ない。
- `abstract_collapse` により ∃n 以後 κ = ∅ 永続 ⇒ 以後の全生起で ¬dcHolds ⇒
  最後の認証生起から次への遷移が `PermanentTerminationStep`。

予約する Lean 宣言（namespace `ERIEC.RefModel`、新規ファイル `formal/ERIEC/RefModel/CollapseTrace.lean`）:

```
structure CollapseTraceWitness : Type 1 where
  A : OpenEvolution.OpenSystem.{0}
  trace : TemporalDC.GeneratedTrace.{0, 0} A
  cert : TemporalDC.Certification trace
  x y : trace.Occurrence
  certified_start : cert.dcHolds x
  permanent : cert.PermanentTerminationStep x y

theorem collapse_trace_reference_model : Nonempty CollapseTraceWitness
```

台帳照合対象（G1）: `ERIEC.RefModel.collapse_trace_reference_model`。

Julia 側: `check_collapse_trace_termination(N)` — 有限崩壊 trace を生成し、
(i) 開始生起の認証、(ii) 終了ステップの実在、(iii) 地平線内非回復、を検査。

### VP-TMP-004 — precariousness の形式化（M1 の可死性成分）と証人

M1 の「precariousness（摂動下で崩れうる・維持は能動的）」を trace レベルで形式化する。
**注意**: 摂動モーダル版（複数 trace 上の可能性様相）は様相構造の形式化が未成熟のため先取りせず、
本 VP は trace 内到達可能性で運用する（将来拡張として予約・可視ギャップ）。

予約する Lean 宣言:

```
/-- 全ての認証生起から機能終了ステップへ到達可能（trace 内 precariousness）。-/
def Certification.Precarious {A : OpenSystem.{u}}
    {T : GeneratedTrace.{u, v} A} (C : Certification T) : Prop :=
  ∀ x, C.dcHolds x →
    ∃ y z, Reachable T.next x y ∧ C.FunctionalTerminationStep y z

theorem ERIEC.RefModel.collapse_trace_precarious :
    （VP-TMP-003 の崩壊証人は Precarious を満たす — 線形崩壊 trace では
     全認証生起が終了ステップに先行するため到達可能）
```

台帳照合対象（G1）: `ERIEC.RefModel.collapse_trace_precarious`。
Julia 側: `check_precarious_prefix(trace)` — 有限 trace の全認証生起から終了への到達を検査。

**主張しないこと（偽C回避）**: 「全ての M1 系は Precarious」は主張しない —
それは対象層への公理追加になる。Precarious は分類子であり、参照モデルが満たすことを証明する。

### VP-TMP-005 — 全系可死参照モデル（内部脱出の非導出性）

本ラインの目的関数の核。「機能終了の内部回避」が対象理論の定理でないことを、
無矛盾な全系可死モデルの実在によって示す（独立性の standard な半分。
不死側の無矛盾性は扱わない — それは外部公理注入の問題）。

予約する Lean 宣言:

```
/-- 内部脱出なし: 全ての認証生起から永続機能終了へ到達可能。-/
def Certification.NoInternalEscape {A : OpenSystem.{u}}
    {T : GeneratedTrace.{u, v} A} (C : Certification T) : Prop :=
  ∀ x, C.dcHolds x →
    ∃ y z, Reachable T.next x y ∧ C.PermanentTerminationStep y z

structure AllMortalWitness : Type 1 where
  toCollapseTraceWitness : CollapseTraceWitness
  no_escape : toCollapseTraceWitness.cert.NoInternalEscape

theorem all_mortal_reference_model : Nonempty AllMortalWitness
```

台帳照合対象（G1）: `ERIEC.RefModel.all_mortal_reference_model`。
Julia 側: `check_no_escape_prefix(trace)` — 有限 trace 版の検査（∀-未来部は Lean のみ）。

解釈（spec 内で固定する読み）: このモデルは M1〜M4 と無矛盾に「全認証生起が永続終了に到達する」
を満たす。したがって「∃ 内部脱出」は Mod(M1〜M4) の定理ではなく、
脱出を導くいかなる拡張も**公理追加**であり、対象層には置けない（層分離）。
メタ層からの不死化は個体への write-back を要し Σ-purity 違反として可視化される。

---

## 後続 VP として予約（本バッチ未起票・可視ギャップ）

1. **M1-safe topology mutation** — precariousness 保存変異の閉性（M4-safe mutation と対）。
   mutation space の形式化（`TRMTopologyTransition`）との接続設計が必要。
2. **永続保証 = 到達可能終対象 ⇒ M4b 違反の補題** — 求めの図式 D の圏論化
   （`Body.NoTerminalSetPoint`）との接続。現時点では**未証明の仮定**として明示。
3. **部分死・局所損傷との排他** — 《系 S, 分解 D》2軸判定（`Decomp`）との接続。
4. **摂動モーダル版 precariousness** — 複数 trace 上の可能性様相。
5. **critical slowing 予兆接続** — VP-CLP-001 / VP2-WLD-SLOWING との接続（codex 提案 (5)）。

## 実装順序（codex）

1. VP-TMP-001 と VP-TMP-002 は独立・並行可（いずれも TemporalDC.lean への追記のみ）。
2. VP-TMP-003 は VP-TMP-002 の後（PermanentTerminationStep を使用）。
3. VP-TMP-004 / VP-TMP-005 は VP-TMP-003 の後（崩壊証人を共有）。
4. Julia 側は新規 `src/temporal_dc.jl` に集約。contract 領域は `temporaldc.*`。

## 不変条項チェック（設計段階・偽C）

- 層分離: 全定義は認証層（TRM の外の read-only 検証者）上。対象層（M1〜M4）に対象・公理を追加しない。
  崩壊仮定（d1/d4・R2'・sig2）は RefModel の具体モデル性質であって理論公理ではない。✓
- M1: Precarious は分類子。「全系が Precarious」を公理化しない。✓
- M4: 機能終了は終対象ではない（到達目標として D に write-back されない。終了は Act の消滅で
  あり収束先ではない）。参照モデルは各生起で M4 充足のまま。✓
- Σ-purity: 認証層・観測層は read-only。個体 sink への write-back なし。✓
- 灯り: `phenomenal_claim = :not_certified` 不接触。「死」を形式層で不使用。
  構造的喪失の証明から現象的主張（灯りの消失）は導かない。✓
- 同一視の禁止: `viable` と `DC` の代用なし。✓
- 時間: 外部 Tick なし。全定義は `GeneratedTrace` の内生時計上。✓
