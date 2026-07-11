import ERIEC

open scoped RealInnerProductSpace

namespace ERIECIntegrationTest

open ERIEC

noncomputable section

/-! A single finite witness crossing the complete Lean proof stack. -/

def unitRel (_ : Unit) : Set Unit := Set.univ

def unitNuPhi : Closure.NuPhi Unit Unit where
  piRel := unitRel
  rhoRel := unitRel
  nuPhi := Set.univ
  isFixedPoint := by
    ext x
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star, unitRel]
  isGreatest := by
    intro Y hY x hx
    trivial

def unitDC : DC Unit Unit Unit Unit where
  alphaRel := unitRel
  sigmaRel := unitRel
  piRel := unitRel
  rhoRel := unitRel
  kappa := fun _ => Set.univ
  epsilon := fun _ => Set.univ
  boundary := Set.univ
  s := ()
  hSelf := by
    intro x hx
    simp [Closure.Phi, Closure.pi_star, Closure.rho_star, unitRel]
  hSMC := by
    intro x hx
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, unitRel]
  hAct := by
    refine ⟨(), ?_⟩
    simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, unitRel]
  hBound := by
    refine ⟨(), ?_⟩
    simp

theorem unit_adjunction :
    GaloisConnection (Adj.alpha_star unitRel)
      (Adj.sigma_star_induced unitRel) :=
  Adj.galoisConn_induced unitRel

theorem unit_closure_fixed :
    Closure.Phi unitNuPhi.piRel unitNuPhi.rhoRel unitNuPhi.nuPhi =
      unitNuPhi.nuPhi :=
  Closure.nuPhi_isFixedPoint unitNuPhi

theorem unit_hinge_nonempty :
    (Hinge.Act unitDC.rhoRel unitDC.sigmaRel
      unitDC.kappa unitDC.epsilon unitDC.s).Nonempty :=
  DC.act_nonempty unitDC

abbrev V₁ := EuclideanSpace ℝ (Fin 1)

def identitySigma (x : V₁) : V₁ := x

def direction : V₁ := EuclideanSpace.basisFun (Fin 1) ℝ 0

theorem direction_ne_zero : direction ≠ 0 := by
  simp [direction]

theorem direction_world_fixed :
    World.WorldFixedVector (World.worldLoop identitySigma 0) direction := by
  have hT : fderiv ℝ identitySigma 0 = ContinuousLinearMap.id ℝ V₁ := by
    change fderiv ℝ (fun x : V₁ => x) 0 = ContinuousLinearMap.id ℝ V₁
    exact (hasFDerivAt_id (𝕜 := ℝ) (x := (0 : V₁))).fderiv
  simp [World.WorldFixedVector, World.worldLoop, Sens.T_w_adjoint,
    Sens.T_w, hT]

def unitIntertwining :
    WorldDC.IntertwiningRepresentation unitDC identitySigma 0 where
  rep := fun _ => direction
  loopDynamics := _root_.id
  chain := by
    intro x
    exact direction_world_fixed
  act_fixed := by
    intro x hx
    rfl
  rep_ne_zero := by
    intro x hx
    exact direction_ne_zero

theorem unit_world_nontrivial :
    World.WldNontrivial (World.worldLoop identitySigma 0) :=
  WorldDC.wldNontrivial_of_intertwining unitIntertwining

def unitThinCategory : Graded.ThinCategory Unit where
  leq := fun _ _ => True
  refl := fun _ => trivial
  trans := fun _ _ => trivial

def unitPresheaf : Graded.Presheaf unitThinCategory where
  Obj := fun _ => Unit
  res := fun _ x => x
  res_id := by intros; rfl
  res_comp := by intros; rfl

def unitPresheafTransition :
    Graded.PresheafTransitionCoproduct unitPresheaf unitPresheaf where
  Tag := Unit
  app := fun _ _ x => x
  natural := by intros; rfl

theorem unit_transition_natural :
    unitPresheaf.res (unitThinCategory.refl ())
        (unitPresheafTransition.app () () ()) =
      unitPresheafTransition.app () ()
        (unitPresheaf.res (unitThinCategory.refl ()) ()) :=
  Graded.presheafTransition_naturality
    unitPresheafTransition () (unitThinCategory.refl ()) ()

theorem structural_weight_without_mattering :
    Value.HasStructuralWeight Value.Countermodel.nuPhi
        Value.Countermodel.contribution () ∧
      ¬ Value.Countermodel.mattering () :=
  ⟨Value.Countermodel.has_structural_weight,
    Value.Countermodel.no_phenomenal_mattering⟩

def guardedUnit : MetaSelection.CertifiedUnit Unit where
  payload := ()

/-- Bundled witness proving that every formal layer can be inhabited and
composed without upgrading the phenomenal marker. -/
structure FormalIntegrationWitness where
  adjunction :
    GaloisConnection (Adj.alpha_star unitRel)
      (Adj.sigma_star_induced unitRel)
  closureFixed :
    Closure.Phi unitNuPhi.piRel unitNuPhi.rhoRel unitNuPhi.nuPhi =
      unitNuPhi.nuPhi
  hingeNonempty :
    (Hinge.Act unitDC.rhoRel unitDC.sigmaRel
      unitDC.kappa unitDC.epsilon unitDC.s).Nonempty
  worldNontrivial :
    World.WldNontrivial (World.worldLoop identitySigma 0)
  transitionNatural :
    unitPresheaf.res (unitThinCategory.refl ())
        (unitPresheafTransition.app () () ()) =
      unitPresheafTransition.app () ()
        (unitPresheaf.res (unitThinCategory.refl ()) ())
  structuralGap :
    Value.HasStructuralWeight Value.Countermodel.nuPhi
        Value.Countermodel.contribution () ∧
      ¬ Value.Countermodel.mattering ()
  trmTopology :
    OpenEvolution.OpenSystem.Adaptive
      TRMTopologyTransition.expandedSystem ∧
    TRMTopologyTransition.expandedViable.viable
      TRMTopologyTransition.observedParent ∧
    TRMTopologyTransition.observedChild ∈
      TRMTopologyTransition.expandedReplicative.reproduce
        TRMTopologyTransition.observedParent ∧
    TRMTopologyTransition.expandedViable.viable
      TRMTopologyTransition.observedChild ∧
    MetaSelection.InternalTrace.M4
      (TRMTopologyTransition.trace ()
        TRMTopologyTransition.observedParent) ∧
    MetaSelection.InternalTrace.M4
      (TRMTopologyTransition.trace ()
        TRMTopologyTransition.observedChild) ∧
    TRMTopologyTransition.richness TRMTopologyTransition.observedParent <
      TRMTopologyTransition.richness TRMTopologyTransition.observedChild ∧
    TRMTopologyTransition.expandedEvolutionary.heritage
        TRMTopologyTransition.observedChild ≠
      TRMTopologyTransition.expandedEvolutionary.heritage
        TRMTopologyTransition.observedParent
  temporalTrace :
    TRMTopologyTransition.relaxationTrace.next
        .plastic .stable ∧
      TRMTopologyTransition.relaxationTrace.state .stable ∈
        TRMTopologyTransition.expandedSystem.step
          (TRMTopologyTransition.relaxationTrace.state .plastic) ∧
      TRMTopologyTransition.relaxationTrace.clock.leq .plastic .stable
  phenomenalGuard :
    guardedUnit.phenomenalClaim = .notCertified
  artifactVersion : certifiedArtifact.version = 1

def integratedWitness : FormalIntegrationWitness where
  adjunction := unit_adjunction
  closureFixed := unit_closure_fixed
  hingeNonempty := unit_hinge_nonempty
  worldNontrivial := unit_world_nontrivial
  transitionNatural := unit_transition_natural
  structuralGap := structural_weight_without_mattering
  trmTopology := TRMTopologyTransition.observedTopologyTransition_certified
  temporalTrace := ⟨TRMTopologyTransition.relaxation_immediate,
    TRMTopologyTransition.relaxation_generated,
    TRMTopologyTransition.relaxation_precedes⟩
  phenomenalGuard := MetaSelection.certifiedUnit_notCertified guardedUnit
  artifactVersion := rfl

theorem integration_test_passes :
    integratedWitness.artifactVersion = rfl ∧
      integratedWitness.phenomenalGuard = rfl := by
  constructor <;> rfl

end

end ERIECIntegrationTest
