import Mathlib.Data.Fintype.Basic

namespace ERIEC
namespace Gate

universe u

/-- Display-level gate values for guarantee propagation. `bridgeOpen` is the
formal name for the document's display value `open`, avoiding the Lean keyword. -/
inductive Gv where
  | pass
  | fail
  | unk
  | bridgeOpen
  | na
deriving DecidableEq, Repr

/-- A displayed value blocks all downstream guarantee components. -/
def Blocks : Gv → Prop
  | .fail => True
  | .na => True
  | _ => False

/-- Recorded reason why neither a proof nor a refutation is currently known. -/
structure UnknownReason where
  label : String
deriving DecidableEq, Repr

/-- Evidence that a dependency has already failed or become inapplicable.
This lives in `Prop`, so the propagated result is independent of which
equivalent blocking witness was selected by well-founded recursion. -/
structure DepFail : Prop where
  blocked : ∃ cause : Gv, Blocks cause

/-- A recorded bridge obligation that is open in the current specification. -/
structure OpenObligation where
  label : String
deriving DecidableEq, Repr

/-- Raw evidence for a component claim. `fail` carries an actual refutation;
absence of a proof is represented by `unk`, not by `fail`. -/
inductive RawEv (P : Prop) where
  | pass : P → RawEv P
  | fail : (¬ P) → RawEv P
  | unk : UnknownReason → RawEv P
  | bridgeOpen : OpenObligation → RawEv P

/-- Propagated gate evidence. `na` is produced by dependency propagation, not
by raw self-report. -/
inductive GateEv (P : Prop) where
  | pass : P → GateEv P
  | fail : (¬ P) → GateEv P
  | unk : UnknownReason → GateEv P
  | bridgeOpen : OpenObligation → GateEv P
  | na : DepFail → GateEv P

def eraseRawEvidence {P : Prop} : RawEv P → Gv
  | .pass _ => .pass
  | .fail _ => .fail
  | .unk _ => .unk
  | .bridgeOpen _ => .bridgeOpen

def eraseEvidence {P : Prop} : GateEv P → Gv
  | .pass _ => .pass
  | .fail _ => .fail
  | .unk _ => .unk
  | .bridgeOpen _ => .bridgeOpen
  | .na _ => .na

def promoteRaw {P : Prop} : RawEv P → GateEv P
  | .pass h => .pass h
  | .fail h => .fail h
  | .unk reason => .unk reason
  | .bridgeOpen obligation => .bridgeOpen obligation

theorem erase_promoteRaw {P : Prop} (raw : RawEv P) :
    eraseEvidence (promoteRaw raw) = eraseRawEvidence raw := by
  cases raw <;> rfl

theorem raw_unk_not_fail {P : Prop} (reason : UnknownReason) :
    eraseRawEvidence (RawEv.unk reason : RawEv P) ≠ Gv.fail := by
  simp [eraseRawEvidence]

theorem gate_unk_not_fail {P : Prop} (reason : UnknownReason) :
    eraseEvidence (GateEv.unk reason : GateEv P) ≠ Gv.fail := by
  simp [eraseEvidence]

theorem raw_pass_sound {P : Prop} {raw : RawEv P}
    (h : eraseRawEvidence raw = Gv.pass) : P := by
  cases raw with
  | pass hp => exact hp
  | fail _ => simp [eraseRawEvidence] at h
  | unk _ => simp [eraseRawEvidence] at h
  | bridgeOpen _ => simp [eraseRawEvidence] at h

theorem raw_fail_sound {P : Prop} {raw : RawEv P}
    (h : eraseRawEvidence raw = Gv.fail) : ¬ P := by
  cases raw with
  | pass _ => simp [eraseRawEvidence] at h
  | fail hn => exact hn
  | unk _ => simp [eraseRawEvidence] at h
  | bridgeOpen _ => simp [eraseRawEvidence] at h

theorem gate_pass_sound {P : Prop} {ev : GateEv P}
    (h : eraseEvidence ev = Gv.pass) : P := by
  cases ev with
  | pass hp => exact hp
  | fail _ => simp [eraseEvidence] at h
  | unk _ => simp [eraseEvidence] at h
  | bridgeOpen _ => simp [eraseEvidence] at h
  | na _ => simp [eraseEvidence] at h

theorem gate_fail_sound {P : Prop} {ev : GateEv P}
    (h : eraseEvidence ev = Gv.fail) : ¬ P := by
  cases ev with
  | pass _ => simp [eraseEvidence] at h
  | fail hn => exact hn
  | unk _ => simp [eraseEvidence] at h
  | bridgeOpen _ => simp [eraseEvidence] at h
  | na _ => simp [eraseEvidence] at h

theorem raw_ne_na {P : Prop} (raw : RawEv P) :
    eraseRawEvidence raw ≠ Gv.na := by
  cases raw <;> simp [eraseRawEvidence]

theorem promoteRaw_ne_na {P : Prop} (raw : RawEv P) :
    eraseEvidence (promoteRaw raw) ≠ Gv.na := by
  simpa [erase_promoteRaw raw] using raw_ne_na raw

/-- Phenomenal raw evidence has no `pass` or `fail` constructor in this
specification; it can only record an open bridge obligation. -/
inductive PhenomenalRaw where
  | bridgeOpen : OpenObligation → PhenomenalRaw

/-- Phenomenal gate evidence after dependency propagation. -/
inductive PhenomenalGate where
  | bridgeOpen : OpenObligation → PhenomenalGate
  | na : DepFail → PhenomenalGate

def erasePhenomenalRaw : PhenomenalRaw → Gv
  | .bridgeOpen _ => .bridgeOpen

def erasePhenomenalGate : PhenomenalGate → Gv
  | .bridgeOpen _ => .bridgeOpen
  | .na _ => .na

theorem phenomenal_range (g : PhenomenalGate) :
    erasePhenomenalGate g = Gv.bridgeOpen ∨ erasePhenomenalGate g = Gv.na := by
  cases g <;> simp [erasePhenomenalGate]

theorem phenomenal_ne_pass (g : PhenomenalGate) :
    erasePhenomenalGate g ≠ Gv.pass := by
  cases g <;> simp [erasePhenomenalGate]

theorem phenomenal_ne_fail (g : PhenomenalGate) :
    erasePhenomenalGate g ≠ Gv.fail := by
  cases g <;> simp [erasePhenomenalGate]

theorem blocks_fail : Blocks Gv.fail := by
  simp [Blocks]

theorem blocks_na : Blocks Gv.na := by
  simp [Blocks]

theorem unk_not_blocks : ¬ Blocks Gv.unk := by
  simp [Blocks]

theorem pass_not_blocks : ¬ Blocks Gv.pass := by
  simp [Blocks]

theorem bridgeOpen_not_blocks : ¬ Blocks Gv.bridgeOpen := by
  simp [Blocks]

theorem blocks_iff (g : Gv) : Blocks g ↔ g = Gv.fail ∨ g = Gv.na := by
  cases g <;> simp [Blocks]

theorem not_blocks_iff (g : Gv) :
    ¬ Blocks g ↔ g = Gv.pass ∨ g = Gv.unk ∨ g = Gv.bridgeOpen := by
  cases g <;> simp [Blocks]

/-- §24.2: dependency data and raw evidence for a guarantee profile. -/
structure GateFrame (Idx : Type u) where
  Claim : Idx → Prop
  dep : Idx → Idx → Prop
  raw : ∀ i, RawEv (Claim i)
  finite : Finite Idx
  wf : WellFounded dep
  phenomenal : Idx → Prop
  phenomenal_raw : ∀ i, phenomenal i →
    ∃ obligation, raw i = RawEv.bridgeOpen obligation

/-- One well-founded recursion step. Only a blocking predecessor can construct
the `na` branch; otherwise raw evidence is promoted unchanged. -/
def HasBlockedPredecessor {Idx : Type u} (G : GateFrame Idx) (i : Idx)
    (prior : ∀ j, G.dep j i → GateEv (G.Claim j)) : Prop :=
  ∃ j, ∃ hj : G.dep j i, Blocks (eraseEvidence (prior j hj))

noncomputable def gateStep {Idx : Type u} (G : GateFrame Idx) (i : Idx)
    (prior : ∀ j, G.dep j i → GateEv (G.Claim j)) : GateEv (G.Claim i) := by
  classical
  by_cases h : HasBlockedPredecessor G i prior
  · let j := Classical.choose h
    let hj := Classical.choose (Classical.choose_spec h)
    have hblock : Blocks (eraseEvidence (prior j hj)) :=
      Classical.choose_spec (Classical.choose_spec h)
    exact GateEv.na ⟨⟨eraseEvidence (prior j hj), hblock⟩⟩
  · exact promoteRaw (G.raw i)

/-- §24.2′: canonical propagated evidence, constructed by recursion over the
well-founded dependency relation. -/
noncomputable def gateEv {Idx : Type u} (G : GateFrame Idx) :
    ∀ i, GateEv (G.Claim i) :=
  G.wf.fix fun i prior ↦ gateStep G i prior

theorem gateEv_eq {Idx : Type u} (G : GateFrame Idx) (i : Idx) :
    gateEv G i = gateStep G i (fun j _ ↦ gateEv G j) := by
  rw [gateEv, WellFounded.fix_eq]

/-- A candidate family satisfies the defining gate recursion pointwise. -/
def GateEquation {Idx : Type u} (G : GateFrame Idx)
    (ev : ∀ i, GateEv (G.Claim i)) : Prop :=
  ∀ i, ev i = gateStep G i (fun j _ ↦ ev j)

theorem gateEv_equation {Idx : Type u} (G : GateFrame Idx) :
    GateEquation G (gateEv G) :=
  gateEv_eq G

theorem gate_exists {Idx : Type u} (G : GateFrame Idx) :
    ∃ ev : ∀ i, GateEv (G.Claim i), GateEquation G ev :=
  ⟨gateEv G, gateEv_equation G⟩

/-- A phenomenal component can only remain open or become inapplicable through
dependency propagation. -/
theorem gateEv_phenomenal_range {Idx : Type u} (G : GateFrame Idx) (i : Idx)
    (hi : G.phenomenal i) :
    eraseEvidence (gateEv G i) = Gv.bridgeOpen ∨
      eraseEvidence (gateEv G i) = Gv.na := by
  rw [gateEv_eq]
  classical
  by_cases h : HasBlockedPredecessor G i (fun j _ ↦ gateEv G j)
  · right
    simp [gateStep, h, eraseEvidence]
  · obtain ⟨obligation, hraw⟩ := G.phenomenal_raw i hi
    left
    simp [gateStep, h, hraw, promoteRaw, eraseEvidence]

/-- A concrete propagated gate assignment for a frame.

`local_na` is the local propagation rule: if `j` is a direct dependency of `i`
and `j` blocks, then `i` is not applicable.
-/
structure GateAssignment {Idx : Type u} (𝒢 : GateFrame Idx) where
  ev : ∀ i, GateEv (𝒢.Claim i)
  local_na : ∀ {j i}, 𝒢.dep j i → Blocks (eraseEvidence (ev j)) →
    eraseEvidence (ev i) = Gv.na

def GateAssignment.gate {Idx : Type u} {𝒢 : GateFrame Idx}
    (assignment : GateAssignment 𝒢) : Idx → Gv :=
  fun i => eraseEvidence (assignment.ev i)

/-- v5.2 §24.3: the well-founded gate recursion has a unique solution. -/
theorem gate_unique {Idx : Type u} {G : GateFrame Idx}
    (candidate : ∀ i, GateEv (G.Claim i))
    (hCandidate : GateEquation G candidate) :
    candidate = gateEv G := by
  funext i
  induction i using G.wf.induction with
  | h i ih =>
      rw [hCandidate i, gateEv_eq]
      unfold gateStep
      classical
      by_cases hc : HasBlockedPredecessor G i (fun j _ ↦ candidate j)
      · have hg : HasBlockedPredecessor G i (fun j _ ↦ gateEv G j) := by
          obtain ⟨j, hj, hblock⟩ := hc
          exact ⟨j, hj, by simpa [ih j hj] using hblock⟩
        simp only [dif_pos hc, dif_pos hg]
      · have hg : ¬ HasBlockedPredecessor G i (fun j _ ↦ gateEv G j) := by
          rintro ⟨j, hj, hblock⟩
          exact hc ⟨j, hj, by simpa [ih j hj] using hblock⟩
        simp only [dif_neg hc, dif_neg hg]

theorem gate_existsUnique {Idx : Type u} (G : GateFrame Idx) :
    ∃! ev : ∀ i, GateEv (G.Claim i), GateEquation G ev := by
  refine ⟨gateEv G, gateEv_equation G, ?_⟩
  intro candidate hCandidate
  exact gate_unique candidate hCandidate

/-- The canonical recursive solution as the compatibility assignment consumed
by the transitive propagation API below. -/
noncomputable def computedAssignment {Idx : Type u} (G : GateFrame Idx) :
    GateAssignment G where
  ev := gateEv G
  local_na := by
    intro j i hdep hblock
    rw [gateEv_eq]
    classical
    have h : HasBlockedPredecessor G i (fun k _ ↦ gateEv G k) :=
      ⟨j, hdep, hblock⟩
    simp [gateStep, h, eraseEvidence]

/-- A frame with no dependency edges: raw evidence is promoted componentwise. -/
def rawOnlyFrame (Idx : Type u) [Finite Idx] (Claim : Idx → Prop)
    (raw : ∀ i, RawEv (Claim i)) : GateFrame Idx where
  Claim := Claim
  dep := fun _ _ => False
  raw := raw
  finite := inferInstance
  wf := by
    refine ⟨fun i ↦ Acc.intro i ?_⟩
    intro j h
    exact False.elim h
  phenomenal := fun _ ↦ False
  phenomenal_raw := by
    intro i h
    exact False.elim h

def rawOnlyAssignment {Idx : Type u} [Finite Idx] {Claim : Idx → Prop}
    (raw : ∀ i, RawEv (Claim i)) :
    GateAssignment (rawOnlyFrame Idx Claim raw) where
  ev := fun i => promoteRaw (raw i)
  local_na := by
    intro j i hdep _hblock
    cases hdep

theorem rawOnly_erases {Idx : Type u} [Finite Idx] {Claim : Idx → Prop}
    (raw : ∀ i, RawEv (Claim i)) (i : Idx) :
    eraseEvidence ((rawOnlyAssignment raw).ev i) = eraseRawEvidence (raw i) :=
  erase_promoteRaw (raw i)

/-- Transitive dependency paths generated by the direct dependency relation. -/
inductive DepPath {Idx : Type u} (dep : Idx → Idx → Prop) : Idx → Idx → Prop where
  | single {j i} : dep j i → DepPath dep j i
  | cons {j k i} : dep j k → DepPath dep k i → DepPath dep j i

namespace DepPath

theorem trans {Idx : Type u} {dep : Idx → Idx → Prop} {a b c : Idx}
    (p : DepPath dep a b) (q : DepPath dep b c) : DepPath dep a c := by
  induction p with
  | single h =>
      exact DepPath.cons h q
  | cons h rest ih =>
      exact DepPath.cons h (ih q)

end DepPath

theorem na_propagates {Idx : Type u} {𝒢 : GateFrame Idx}
    (gate : GateAssignment 𝒢) {j i : Idx}
    (path : DepPath 𝒢.dep j i)
    (hblock : Blocks (eraseEvidence (gate.ev j))) :
    eraseEvidence (gate.ev i) = Gv.na := by
  induction path with
  | single hdep =>
      exact gate.local_na hdep hblock
  | cons hdep rest ih =>
      have hk : eraseEvidence (gate.ev _) = Gv.na :=
        gate.local_na hdep hblock
      exact ih (by simpa [hk] using blocks_na)

theorem gate_na_propagates {Idx : Type u} {𝒢 : GateFrame Idx}
    (assignment : GateAssignment 𝒢) {j i : Idx}
    (path : DepPath 𝒢.dep j i)
    (hblock : Blocks (assignment.gate j)) :
    assignment.gate i = Gv.na :=
  na_propagates assignment path hblock

theorem na_propagates_of_fail {Idx : Type u} {𝒢 : GateFrame Idx}
    (gate : GateAssignment 𝒢) {j i : Idx}
    (path : DepPath 𝒢.dep j i)
    (hfail : eraseEvidence (gate.ev j) = Gv.fail) :
    eraseEvidence (gate.ev i) = Gv.na := by
  exact na_propagates gate path (by simpa [hfail] using blocks_fail)

theorem na_propagates_of_na {Idx : Type u} {𝒢 : GateFrame Idx}
    (gate : GateAssignment 𝒢) {j i : Idx}
    (path : DepPath 𝒢.dep j i)
    (hna : eraseEvidence (gate.ev j) = Gv.na) :
    eraseEvidence (gate.ev i) = Gv.na := by
  exact na_propagates gate path (by simpa [hna] using blocks_na)

end Gate
end ERIEC
