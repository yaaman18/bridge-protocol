import ERIEC.WorldDC

open scoped RealInnerProductSpace

namespace ERIEC

namespace WorldDC

/-!
# Representation map: discrete double closure → actuated-world fixed vector

`WorldDC.lean` records only a *consistency harness*: its `DCWorldBridge`
already carries a nonzero fixed direction of the loop as a field, so the
discrete `DC` witness does no work in producing the world side. The forward
half of Prop 5.3 (`DC → WldNontrivial`) is therefore *assumed*, not derived.

This file narrows that gap with a **representation map**
`rep : M → EuclideanSpace ℝ (Fin m)` from discrete actions to the action
Hilbert space. Both levels give a *conditional* forward — `DC` together with a
representation gives `WldNontrivial` — NOT an unconditional `DC → WldNontrivial`.

Two levels:

* `SensorimotorRepresentation` (Level 1): posits the coherence axiom
  `rep_fixed` (viable actions map to fixed vectors of `L = T^* ∘ T`).
  IMPORTANT: `rep_fixed` is conclusion-equivalent — it asserts the world-side
  fixed vector for each `Act` witness — so `wldNontrivial_of_representation`
  is NOT a derivation of `DC → Wld`; it is a *conditional forward assuming a
  representation*. The only genuine gain over `DCWorldBridge` is that the
  produced `direction` is sourced from the discrete witness `dc.hAct` (via
  `bridge_of_representation`) rather than assumed standalone. The real
  reduction happens at Level 2.

* `IntertwiningRepresentation` (Level 2): replaces the coherence axiom by a
  **naturality square** `L ∘ rep = rep ∘ δ` (chain map) together with the
  transported operational closure `δ x = x` on viable actions. `rep_fixed`
  is then a *theorem* (`rep_fixed_of_intertwining`): no fixed vector is
  assumed — chain (an L-referencing coherence condition) and `act_fixed` (an
  M-side condition) are non-circular, and the fixed nonzero vector is actually
  constructed from `rep_ne_zero` and `dc.hAct`. This is still a *conditional*
  forward (it assumes `chain` + `act_fixed`), not unconditional `DC → Wld`.

What stays open (honest scope):
* The reverse direction `WldNontrivial → DC` is still unprovable from `Wld`
  alone (it cannot reconstruct `kappa`/`boundary`/hinge witnesses). This file
  upgrades only the forward half; full Prop 5.3 equivalence is *not* claimed.
* `dc.hSMC` lives on subsets of `E`, while `act_fixed` is a pointwise claim
  about an endomap on `M`; `hSMC` alone cannot derive it. A next layer needs
  an explicit action dynamics constructed through `epsilon`/`sigmaRel`, plus
  a lemma showing that dynamics fixes `Act`. Likewise, identifying a partial
  isometry's projection with the discrete closure still requires image,
  faithfulness, and intertwining hypotheses for `rep`.
-/

variable {M E C S : Type*} {m e : Nat}

/-- **Level 1.** A representation of discrete actions as vectors in the action
Hilbert space, coherent with the world loop on viable (hinge) actions. -/
structure SensorimotorRepresentation
    (dc : DC M E C S)
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) where
  /-- representation of a discrete action as an action-space vector -/
  rep : M → EuclideanSpace ℝ (Fin m)
  /-- nondegeneracy: viable actions are represented by nonzero vectors -/
  rep_ne_zero : ∀ {x : M},
    x ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s → rep x ≠ 0
  /-- coherence: a viable action maps to a fixed vector of `L = T^* ∘ T` -/
  rep_fixed : ∀ {x : M},
    x ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s →
      World.WorldFixedVector (World.worldLoop sigma a) (rep x)

/-- Conditional forward (Level 1): *assuming a `SensorimotorRepresentation`*,
the discrete hinge witness `dc.hAct` is transported through `rep` to a nonzero
fixed direction. This is NOT an unconditional `DC → Wld`: the coherence axiom
`rep_fixed` already asserts the world-side conclusion for each `Act` witness. -/
theorem wldNontrivial_of_representation
    {dc : DC M E C S}
    {sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e)}
    {a : EuclideanSpace ℝ (Fin m)}
    (R : SensorimotorRepresentation dc sigma a) :
    World.WldNontrivial (World.worldLoop sigma a) := by
  obtain ⟨x, hx⟩ := dc.hAct
  exact ⟨R.rep x, R.rep_ne_zero hx, R.rep_fixed hx⟩

/-- The representation *refines* the old harness: it constructs a
`DCWorldBridge` whose `direction` comes from `rep` applied to a real `Act`
element, instead of being assumed standalone. `noncomputable` because pulling
a witness out of the propositional `dc.hAct : (Act ...).Nonempty` into the
`DCWorldBridge.direction` *data* field requires choice. -/
noncomputable def bridge_of_representation
    {dc : DC M E C S}
    {sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e)}
    {a : EuclideanSpace ℝ (Fin m)}
    (R : SensorimotorRepresentation dc sigma a) :
    DCWorldBridge dc (World.worldLoop sigma a) where
  direction := R.rep dc.hAct.some
  direction_nonzero := R.rep_ne_zero dc.hAct.some_mem
  direction_fixed := R.rep_fixed dc.hAct.some_mem

/-- **Level 2.** A representation that is a **chain map** for a discrete action
loop `δ = loopDynamics`, with operational closure (`δ`-fixedness) on viable
actions. No fixed vector is assumed; `rep_fixed` becomes a theorem below. -/
structure IntertwiningRepresentation
    (dc : DC M E C S)
    (sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) where
  /-- representation of a discrete action as an action-space vector -/
  rep : M → EuclideanSpace ℝ (Fin m)
  /-- the discrete action loop `δ` (continuous analog: the loop `L`) -/
  loopDynamics : M → M
  /-- naturality square: `L ∘ rep = rep ∘ δ` -/
  chain : ∀ x : M,
    (World.worldLoop sigma a) (rep x) = rep (loopDynamics x)
  /-- transported operational closure: viable actions are `δ`-fixed -/
  act_fixed : ∀ {x : M},
    x ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s →
      loopDynamics x = x
  /-- nondegeneracy: viable actions are represented by nonzero vectors -/
  rep_ne_zero : ∀ {x : M},
    x ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s → rep x ≠ 0

/-- The coherence axiom of Level 1 is a *theorem* at Level 2: chain map plus
discrete fixed point gives a fixed vector. This is where the representation
actually does the work the old harness assumed. -/
theorem rep_fixed_of_intertwining
    {dc : DC M E C S}
    {sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e)}
    {a : EuclideanSpace ℝ (Fin m)}
    (R : IntertwiningRepresentation dc sigma a)
    {x : M}
    (hx : x ∈ Hinge.Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s) :
    World.WorldFixedVector (World.worldLoop sigma a) (R.rep x) := by
  show (World.worldLoop sigma a) (R.rep x) = R.rep x
  rw [R.chain x, R.act_fixed hx]

/-- Every intertwining representation induces a Level 1 representation. -/
def IntertwiningRepresentation.toSensorimotor
    {dc : DC M E C S}
    {sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e)}
    {a : EuclideanSpace ℝ (Fin m)}
    (R : IntertwiningRepresentation dc sigma a) :
    SensorimotorRepresentation dc sigma a where
  rep := R.rep
  rep_ne_zero := R.rep_ne_zero
  rep_fixed := fun hx => rep_fixed_of_intertwining R hx

/-- Forward half of Prop 5.3 from the fully reduced (Level 2) hypotheses:
no fixed vector assumed, only naturality and operational closure. -/
theorem wldNontrivial_of_intertwining
    {dc : DC M E C S}
    {sigma : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e)}
    {a : EuclideanSpace ℝ (Fin m)}
    (R : IntertwiningRepresentation dc sigma a) :
    World.WldNontrivial (World.worldLoop sigma a) :=
  wldNontrivial_of_representation R.toSensorimotor

end WorldDC

end ERIEC
