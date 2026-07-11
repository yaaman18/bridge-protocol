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

/-- A recorded bridge obligation that is open in the current specification. -/
structure OpenObligation where
  label : String
deriving DecidableEq, Repr

/-- Raw evidence for a component claim. `fail` carries an actual refutation;
absence of a proof is represented by `unk`, not by `fail`. -/
inductive RawEv (P : Prop) where
  | pass : P → RawEv P
  | fail : (¬ P) → RawEv P
  | unk : RawEv P
  | bridgeOpen : OpenObligation → RawEv P

/-- Propagated gate evidence. `na` is produced by dependency propagation, not
by raw self-report. -/
inductive GateEv (P : Prop) where
  | pass : P → GateEv P
  | fail : (¬ P) → GateEv P
  | unk : GateEv P
  | bridgeOpen : OpenObligation → GateEv P
  | na : GateEv P

def eraseRawEvidence {P : Prop} : RawEv P → Gv
  | .pass _ => .pass
  | .fail _ => .fail
  | .unk => .unk
  | .bridgeOpen _ => .bridgeOpen

def eraseEvidence {P : Prop} : GateEv P → Gv
  | .pass _ => .pass
  | .fail _ => .fail
  | .unk => .unk
  | .bridgeOpen _ => .bridgeOpen
  | .na => .na

def promoteRaw {P : Prop} : RawEv P → GateEv P
  | .pass h => .pass h
  | .fail h => .fail h
  | .unk => .unk
  | .bridgeOpen obligation => .bridgeOpen obligation

theorem erase_promoteRaw {P : Prop} (raw : RawEv P) :
    eraseEvidence (promoteRaw raw) = eraseRawEvidence raw := by
  cases raw <;> rfl

theorem raw_unk_not_fail {P : Prop} : eraseRawEvidence (RawEv.unk : RawEv P) ≠ Gv.fail := by
  simp [eraseRawEvidence]

theorem gate_unk_not_fail {P : Prop} : eraseEvidence (GateEv.unk : GateEv P) ≠ Gv.fail := by
  simp [eraseEvidence]

theorem raw_pass_sound {P : Prop} {raw : RawEv P}
    (h : eraseRawEvidence raw = Gv.pass) : P := by
  cases raw with
  | pass hp => exact hp
  | fail _ => simp [eraseRawEvidence] at h
  | unk => simp [eraseRawEvidence] at h
  | bridgeOpen _ => simp [eraseRawEvidence] at h

theorem raw_fail_sound {P : Prop} {raw : RawEv P}
    (h : eraseRawEvidence raw = Gv.fail) : ¬ P := by
  cases raw with
  | pass _ => simp [eraseRawEvidence] at h
  | fail hn => exact hn
  | unk => simp [eraseRawEvidence] at h
  | bridgeOpen _ => simp [eraseRawEvidence] at h

theorem gate_pass_sound {P : Prop} {ev : GateEv P}
    (h : eraseEvidence ev = Gv.pass) : P := by
  cases ev with
  | pass hp => exact hp
  | fail _ => simp [eraseEvidence] at h
  | unk => simp [eraseEvidence] at h
  | bridgeOpen _ => simp [eraseEvidence] at h
  | na => simp [eraseEvidence] at h

theorem gate_fail_sound {P : Prop} {ev : GateEv P}
    (h : eraseEvidence ev = Gv.fail) : ¬ P := by
  cases ev with
  | pass _ => simp [eraseEvidence] at h
  | fail hn => exact hn
  | unk => simp [eraseEvidence] at h
  | bridgeOpen _ => simp [eraseEvidence] at h
  | na => simp [eraseEvidence] at h

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
  | na : PhenomenalGate

def erasePhenomenalRaw : PhenomenalRaw → Gv
  | .bridgeOpen _ => .bridgeOpen

def erasePhenomenalGate : PhenomenalGate → Gv
  | .bridgeOpen _ => .bridgeOpen
  | .na => .na

theorem phenomenal_range (g : PhenomenalGate) :
    erasePhenomenalGate g = Gv.bridgeOpen ∨ erasePhenomenalGate g = Gv.na := by
  cases g <;> simp [erasePhenomenalGate]

theorem phenomenal_ne_pass (g : PhenomenalGate) :
    erasePhenomenalGate g ≠ Gv.pass := by
  cases g <;> simp [erasePhenomenalGate]

theorem phenomenal_ne_fail (g : PhenomenalGate) :
    erasePhenomenalGate g ≠ Gv.fail := by
  cases g <;> simp [erasePhenomenalGate]

/-- A displayed value blocks all downstream guarantee components. -/
def Blocks : Gv → Prop
  | .fail => True
  | .na => True
  | _ => False

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

/-- A frame with no dependency edges: raw evidence is promoted componentwise. -/
def rawOnlyFrame (Idx : Type u) (Claim : Idx → Prop)
    (raw : ∀ i, RawEv (Claim i)) : GateFrame Idx where
  Claim := Claim
  dep := fun _ _ => False
  raw := raw

def rawOnlyAssignment {Idx : Type u} {Claim : Idx → Prop}
    (raw : ∀ i, RawEv (Claim i)) :
    GateAssignment (rawOnlyFrame Idx Claim raw) where
  ev := fun i => promoteRaw (raw i)
  local_na := by
    intro j i hdep _hblock
    cases hdep

theorem rawOnly_erases {Idx : Type u} {Claim : Idx → Prop}
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
