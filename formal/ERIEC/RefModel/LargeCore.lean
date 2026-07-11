import ERIEC.RefModel.Large
import ERIEC.WorldDC

namespace ERIEC
namespace RefModel

open Dynamics

def largeRefPhi {k : ℕ} (w : Bool) (_ : Set (Fin k)) : Set (Fin k) :=
  if w then ∅ else Set.univ

def largeRefTheta {k : ℕ} := (largeRefPhi : Bool → Set (Fin k) → Set (Fin k))

noncomputable def largeRefDrift {k : ℕ} (w : Bool) (K : Set (Fin k)) : Bool :=
  by
    classical
    exact if w = false ∧ K.Nonempty then true else w

def largeRefKappa (k : ℕ) : RefState → Set (Fin k)
  | .s0 | .s1 => Set.univ
  | .s2 => ∅

def largeRefEpsilon := largeRefKappa

noncomputable def largeDynFrame (k : ℕ) (hk : 0 < k) :
    DynFrame (Fin k) (Fin k) Bool RefState where
  phi := largeRefPhi
  theta := largeRefTheta
  drift := largeRefDrift
  kappa := largeRefKappa k
  epsilon := largeRefEpsilon k
  omega := refRank
  stepInt := refStep
  h_int := by
    classical
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    intro s t h
    subst t
    cases s <;> simp [next, largeRefKappa, largeRefEpsilon, refRank,
      largeRefPhi, largeRefTheta, largeRefDrift, Dynamics.upd]

noncomputable def largeTotalNext (k : ℕ) (hk : 0 < k) :
    TotalNext (largeDynFrame k hk).stepInt where
  next := next
  next_internal := by intro s; rfl

def largeRefExternal (_ _ : RefState) : Prop := False

def largeRefCore (k : ℕ) (s : RefState) : Set (Fin k) :=
  largeRefKappa k s

def largeRefCoreIso {k : ℕ} (K K' : Set (Fin k)) : Prop := K = K'

/-- A finite arbitrary-size DC attached to the standard reference state orbit. -/
def largeAXCoreDC (k : ℕ) (hk : 0 < k) : DC (Fin k) (Fin k) (Fin k) RefState where
  alphaRel := finFullRelation
  sigmaRel := finFullRelation
  piRel := finFullRelation
  rhoRel := finFullRelation
  kappa := largeRefKappa k
  epsilon := largeRefEpsilon k
  boundary := Set.univ
  s := .s0
  hSelf := by
    classical
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    intro c _
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star, finFullRelation,
      largeRefKappa]
  hSMC := by
    classical
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    intro e _
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, finFullRelation,
      largeRefEpsilon, largeRefKappa]
  hAct := by
    classical
    letI : Nonempty (Fin k) := ⟨⟨0, hk⟩⟩
    let a : Fin k := ⟨0, hk⟩
    exact ⟨a, by simp [Hinge.Act, Closure.rho_star, Adj.sigma_star,
      finFullRelation, largeRefEpsilon, largeRefKappa]⟩
  hBound := by
    let c : Fin k := ⟨0, hk⟩
    exact ⟨c, by simp [largeRefKappa]⟩

theorem largeRefDrift_r2prime {k : ℕ} :
    R2Prime (largeRefDrift : Bool → Set (Fin k) → Bool) := by
  constructor
  · intro w K
    cases w <;> classical simp [largeRefDrift]
  · intro w K hK hTop
    cases w
    · classical simp [largeRefDrift, hK]
    · exact (hTop rfl).elim

theorem largeRefE5 (k : ℕ) :
    Invariance.E5 largeRefExternal (largeRefCore k)
      (largeRefCoreIso : Set (Fin k) → Set (Fin k) → Prop) := by
  constructor
  intro s s' t _ hExt
  exact hExt.elim

structure LargeStableReferenceWitness (k : ℕ) : Type where
  positive : 0 < k
  dc : DC (Fin k) (Fin k) (Fin k) RefState
  frame : DynFrame (Fin k) (Fin k) Bool RefState
  total : TotalNext frame.stepInt
  dc_eq : dc = largeAXCoreDC k positive
  frame_eq : frame = largeDynFrame k positive
  action_card : Fintype.card (Fin k) = k
  environment_card : Fintype.card (Fin k) = k
  core_card : Fintype.card (Fin k) = k
  multivalued : ∃ a e₁ e₂ : Fin k,
    e₁ ≠ e₂ ∧ e₁ ∈ dc.alphaRel a ∧ e₂ ∈ dc.alphaRel a
  hinge_nonempty :
    (Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty
  internal_total : InternallyTotal frame.stepInt

structure LargeDynamicReferenceWitness (k : ℕ) : Type where
  stable : LargeStableReferenceWitness k
  r2 : R2Prime (largeRefDrift : Bool → Set (Fin k) → Bool)
  e5 : Invariance.E5 largeRefExternal (largeRefCore k)
    (largeRefCoreIso : Set (Fin k) → Set (Fin k) → Prop)

structure LargeAXCoreReferenceWitness (k : ℕ) : Type where
  stable : LargeStableReferenceWitness k
  dynamic : LargeDynamicReferenceWitness k
  same_stable : dynamic.stable = stable

noncomputable def largeStableWorldBridge (k : ℕ) (hk : 0 < k) :
    WorldDC.DCWorldBridge (largeAXCoreDC k hk) stableWorld where
  direction := EuclideanSpace.single 0 1
  direction_nonzero := by
    simp
  direction_fixed := by
    simp [World.WorldFixedVector, stableWorld]

structure LargeThreeLayerReferenceWitness (k : ℕ) : Type where
  tier1 : LargeAXCoreReferenceWitness k
  bridge : WorldDC.DCWorldBridge tier1.stable.dc stableWorld
  world_nontrivial : World.WldNontrivial stableWorld
  value_one : Value.normalized_V ({()} : Finset Unit) (fun _ : Unit => {()}) () = 1
  section13_2 : NondegenerateReferenceWitness

/-- M-1 full Tier-1: for every `k ≥ 2`, the current v5.1
`AX_core = AX_stable ∪ AX_dyn` discrete/dynamic fragment has an arbitrary-size
finite nondegenerate reference witness. World/Value nontriviality is reserved
for the later Tier-2 statement. -/
theorem arbitrarily_large_ax_core_discrete_model (k : ℕ) (hk : 2 ≤ k) :
    Nonempty (LargeAXCoreReferenceWitness k) := by
  let hpos : 0 < k := lt_of_lt_of_le (by decide) hk
  let a : Fin k := ⟨0, hpos⟩
  let e₁ : Fin k := ⟨0, hpos⟩
  let e₂ : Fin k := ⟨1, hk⟩
  let dc := largeAXCoreDC k hpos
  let frame := largeDynFrame k hpos
  let stable : LargeStableReferenceWitness k := {
    positive := hpos
    dc := dc
    frame := frame
    total := largeTotalNext k hpos
    dc_eq := rfl
    frame_eq := rfl
    action_card := by simp
    environment_card := by simp
    core_card := by simp
    multivalued := by
      refine ⟨a, e₁, e₂, ?_, ?_, ?_⟩
      · simp [e₁, e₂]
      · simp [dc, largeAXCoreDC, finFullRelation]
      · simp [dc, largeAXCoreDC, finFullRelation]
    hinge_nonempty := dc.hAct
    internal_total := (largeTotalNext k hpos).internallyTotal
  }
  let dynamic : LargeDynamicReferenceWitness k := {
    stable := stable
    r2 := largeRefDrift_r2prime
    e5 := largeRefE5 k
  }
  exact ⟨{
    stable := stable
    dynamic := dynamic
    same_stable := rfl
  }⟩

/-- M-1 full Tier-2 shape: the arbitrary-size discrete/dynamic witness can be
paired with the existing nontrivial World/Value witnesses and the certified
§13.2 nondegenerate reference obligations. This remains a bridge-shaped
consistency witness, not an unconditional DC↔World equivalence. -/
theorem arbitrarily_large_three_layer_reference_model (k : ℕ) (hk : 2 ≤ k) :
    Nonempty (LargeThreeLayerReferenceWitness k) := by
  obtain ⟨tier1⟩ := arbitrarily_large_ax_core_discrete_model k hk
  obtain ⟨section13_2⟩ := nondegenerate_reference_model
  refine ⟨{
    tier1 := tier1
    bridge := ?_
    world_nontrivial := stableWorld_nontrivial
    value_one := stableValue_one
    section13_2 := section13_2
  }⟩
  rw [tier1.stable.dc_eq]
  exact largeStableWorldBridge k tier1.stable.positive

end RefModel
end ERIEC
