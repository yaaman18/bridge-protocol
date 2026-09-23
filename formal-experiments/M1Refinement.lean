import ERIEC.Closure
import ERIEC.Hinge
import ERIEC.DC

/-
判断記録(2026-09-23 ユーザー決定):
M1R 実装指示書 v2 の G5(docstring は節番号への参照のみ)と §3.4 の宣言台帳(説明文つき
docstring)が矛盾していたため、§3.4 を優先した。§3.4 の宣言の docstring は先頭を節番号
(`M1R-v2 §3.4:`)にそろえたうえで、台帳の説明文を残している。
G5 を優先する判断に戻す場合は、§3.4 の docstring から `:` 以降の説明文を削るだけでよく、
宣言の名前・主張・証明は変わらない。
-/

namespace ERIEC.M1R

/-! ### §3.1 -/

/-- M1R-v2 §3.1 -/
def Psi {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (Y : Set C) : Set C :=
  {c | ∃ a ∈ rhoRel c, (piRel a ∩ Y).Nonempty}

/-- M1R-v2 §3.1 -/
def Phi2 {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (Y : Set C) : Set C :=
  Closure.Phi piRel rhoRel Y ∩ Psi piRel rhoRel Y

/-- M1R-v2 §3.1 -/
def PostFixed2 {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (K : Set C) : Prop :=
  K ⊆ Phi2 piRel rhoRel K

/-- M1R-v2 §3.1 -/
theorem psi_mono {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M) :
    Monotone (Psi piRel rhoRel) := by
  intro Y Z hYZ c hc
  obtain ⟨a, ha, x, hxPi, hxY⟩ := hc
  exact ⟨a, ha, x, hxPi, hYZ hxY⟩

/-- M1R-v2 §3.1 -/
theorem phi2_mono {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M) :
    Monotone (Phi2 piRel rhoRel) := by
  intro Y Z hYZ c hc
  exact ⟨Closure.phi_mono piRel rhoRel hYZ hc.1, psi_mono piRel rhoRel hYZ hc.2⟩

/-- M1R-v2 §3.1 -/
theorem phi2_subset_phi {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (Y : Set C) :
    Phi2 piRel rhoRel Y ⊆ Closure.Phi piRel rhoRel Y :=
  fun _ hc => hc.1

/-- M1R-v2 §3.1 -/
theorem nu_phi2_subset_nu_phi {M C : Type*} (piRel : M → Set C)
    (rhoRel : C → Set M) :
    Closure.nu (Phi2 piRel rhoRel) ⊆ Closure.nu (Closure.Phi piRel rhoRel) :=
  Closure.coinduction
    ((Closure.nu_postfixed (phi2_mono piRel rhoRel)).trans
      (phi2_subset_phi piRel rhoRel _))

/-- M1R-v2 §3.1 -/
theorem nu_phi2_postfixed {M C : Type*} (piRel : M → Set C)
    (rhoRel : C → Set M) :
    PostFixed2 piRel rhoRel (Closure.nu (Phi2 piRel rhoRel)) :=
  Closure.nu_postfixed (phi2_mono piRel rhoRel)

/-! ### §3.2 -/

/-- M1R-v2 §3.2 -/
def IrredUnit {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (U : Set C) : Prop :=
  U.Nonempty ∧ PostFixed2 piRel rhoRel U ∧
    ∀ V, V ⊆ U → V.Nonempty → PostFixed2 piRel rhoRel V → V = U

/-- M1R-v2 §3.2 -/
def NonSingleton {C : Type*} (U : Set C) : Prop :=
  ∃ x ∈ U, ∃ y ∈ U, x ≠ y

/-! ### §3.3 -/

/-- M1R-v2 §3.3 -/
def beta {M E C S : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (sigmaRel : E → Set M) (kappa : S → Set C) (epsilon : S → Set E)
    (s : S) : Set C :=
  kappa s ∩ Closure.pi_star piRel (Hinge.Act rhoRel sigmaRel kappa epsilon s)

/-- M1R-v2 §3.3 -/
theorem beta_subset_kappa {M E C S : Type*} (piRel : M → Set C)
    (rhoRel : C → Set M) (sigmaRel : E → Set M) (kappa : S → Set C)
    (epsilon : S → Set E) (s : S) :
    beta piRel rhoRel sigmaRel kappa epsilon s ⊆ kappa s :=
  fun _ hc => hc.1

/-- M1R-v2 §3.3 -/
theorem beta_subset_phi {M E C S : Type*} (piRel : M → Set C)
    (rhoRel : C → Set M) (sigmaRel : E → Set M) (kappa : S → Set C)
    (epsilon : S → Set E) (s : S) :
    beta piRel rhoRel sigmaRel kappa epsilon s ⊆
      Closure.Phi piRel rhoRel (kappa s) := by
  intro c hc
  have hAct : Hinge.Act rhoRel sigmaRel kappa epsilon s ⊆
      Closure.rho_star rhoRel (kappa s) := fun _ hm => hm.1
  exact Closure.pi_star_mono piRel hAct hc.2

/-! ### §3.4 -/

/-- M1R-v2 §3.4: 行為集合 A を取り除いた関係 -/
def rhoNH {M C : Type*} (rhoRel : C → Set M) (A : Set M) : C → Set M :=
  fun c => rhoRel c \ A

/-- M1R-v2 §3.4: V の内部に、A に属する行為による辺がある -/
def HingeEdgeIn {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (A : Set M) (V : Set C) : Prop :=
  ∃ a ∈ A, a ∈ Closure.rho_star rhoRel V ∧ (piRel a ∩ V).Nonempty

/-- M1R-v2 §3.4: 蝶番の行為を使わずには、κ のどの空でない部分も自己維持しない -/
def HingeNeeded {M E C S : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (sigmaRel : E → Set M) (kappa : S → Set C) (epsilon : S → Set E)
    (s : S) : Prop :=
  ∀ V, V ⊆ kappa s → V.Nonempty →
    ¬ PostFixed2 piRel (rhoNH rhoRel (Hinge.Act rhoRel sigmaRel kappa epsilon s)) V

private theorem aux_mem_rho_star {M C : Type*} (rhoRel : C → Set M) (V : Set C)
    (m : M) : m ∈ Closure.rho_star rhoRel V ↔ ∃ c, c ∈ V ∧ m ∈ rhoRel c := by
  simp [Closure.rho_star]

private theorem aux_mem_pi_star {M C : Type*} (piRel : M → Set C) (A : Set M)
    (c : C) : c ∈ Closure.pi_star piRel A ↔ ∃ m, m ∈ A ∧ c ∈ piRel m := by
  simp [Closure.pi_star]

private theorem aux_mem_phi {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (V : Set C) (c : C) :
    c ∈ Closure.Phi piRel rhoRel V ↔
      ∃ m, m ∈ Closure.rho_star rhoRel V ∧ c ∈ piRel m :=
  aux_mem_pi_star piRel _ c

/-- M1R-v2 §3.4: 除去した関係での自己維持は、元の関係での自己維持を含意する -/
theorem postfixed2_of_rhoNH {M C : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (A : Set M) (V : Set C) :
    PostFixed2 piRel (rhoNH rhoRel A) V → PostFixed2 piRel rhoRel V := by
  intro hV c hc
  obtain ⟨hPhi, a, ha, hne⟩ := hV hc
  refine ⟨?_, a, ha.1, hne⟩
  obtain ⟨m, hmR, hcm⟩ := (aux_mem_phi _ _ _ _).1 hPhi
  obtain ⟨c0, hc0, hm⟩ := (aux_mem_rho_star _ _ _).1 hmR
  exact (aux_mem_phi _ _ _ _).2 ⟨m, (aux_mem_rho_star _ _ _).2 ⟨c0, hc0, hm.1⟩, hcm⟩

/-- M1R-v2 §3.4: 鍵補題: V の内部に A の辺がなければ、A を除去しても V は自己維持する -/
theorem postfixed2_rhoNH_of_no_edge {M C : Type*} (piRel : M → Set C)
    (rhoRel : C → Set M) (A : Set M) (V : Set C)
    (hV : PostFixed2 piRel rhoRel V) (hno : ¬ HingeEdgeIn piRel rhoRel A V) :
    PostFixed2 piRel (rhoNH rhoRel A) V := by
  have hnot : ∀ a, a ∈ Closure.rho_star rhoRel V → (piRel a ∩ V).Nonempty → a ∉ A :=
    fun a hR hne hA => hno ⟨a, hA, hR, hne⟩
  intro c hc
  obtain ⟨hPhi, a, ha, hne⟩ := hV hc
  have haR : a ∈ Closure.rho_star rhoRel V := (aux_mem_rho_star _ _ _).2 ⟨c, hc, ha⟩
  refine ⟨?_, a, ⟨ha, hnot a haR hne⟩, hne⟩
  obtain ⟨m, hmR, hcm⟩ := (aux_mem_phi _ _ _ _).1 hPhi
  obtain ⟨c0, hc0, hm⟩ := (aux_mem_rho_star _ _ _).1 hmR
  exact (aux_mem_phi _ _ _ _).2
    ⟨m, (aux_mem_rho_star _ _ _).2 ⟨c0, hc0, hm, hnot m hmR ⟨c, hcm, hc⟩⟩, hcm⟩

/-- M1R-v2 §3.4: HingeNeeded のもとで、κ 内の空でない自己維持部分は必ず蝶番の辺を内部に持つ -/
theorem hinge_edge_of_postfixed2 {M E C S : Type*} {piRel : M → Set C}
    {rhoRel : C → Set M} {sigmaRel : E → Set M} {kappa : S → Set C}
    {epsilon : S → Set E} {s : S}
    (h : HingeNeeded piRel rhoRel sigmaRel kappa epsilon s)
    (V : Set C) (hVk : V ⊆ kappa s) (hne : V.Nonempty)
    (hV : PostFixed2 piRel rhoRel V) :
    HingeEdgeIn piRel rhoRel (Hinge.Act rhoRel sigmaRel kappa epsilon s) V := by
  by_contra hno
  exact h V hVk hne (postfixed2_rhoNH_of_no_edge piRel rhoRel _ V hV hno)

/-- M1R-v2 §3.4 -/
theorem beta_nonempty_of_hingeNeeded {M E C S : Type*} {piRel : M → Set C}
    {rhoRel : C → Set M} {sigmaRel : E → Set M} {kappa : S → Set C}
    {epsilon : S → Set E} {s : S}
    (h : HingeNeeded piRel rhoRel sigmaRel kappa epsilon s)
    (hSelf : PostFixed2 piRel rhoRel (kappa s)) (hne : (kappa s).Nonempty) :
    (beta piRel rhoRel sigmaRel kappa epsilon s).Nonempty := by
  obtain ⟨a, haAct, -, c, hca, hcK⟩ :=
    hinge_edge_of_postfixed2 h (kappa s) subset_rfl hne hSelf
  exact ⟨c, hcK, (aux_mem_pi_star _ _ _).2 ⟨a, haAct, hca⟩⟩

/-- M1R-v2 §3.4 -/
theorem act_nonempty_of_hingeNeeded {M E C S : Type*} {piRel : M → Set C}
    {rhoRel : C → Set M} {sigmaRel : E → Set M} {kappa : S → Set C}
    {epsilon : S → Set E} {s : S}
    (h : HingeNeeded piRel rhoRel sigmaRel kappa epsilon s)
    (hSelf : PostFixed2 piRel rhoRel (kappa s)) (hne : (kappa s).Nonempty) :
    (Hinge.Act rhoRel sigmaRel kappa epsilon s).Nonempty := by
  obtain ⟨a, haAct, -⟩ := hinge_edge_of_postfixed2 h (kappa s) subset_rfl hne hSelf
  exact ⟨a, haAct⟩

/-! ### §3.5 -/

/-- M1R-v2 §3.5 -/
structure DC2 (M E C S : Type*) where
  alphaRel : M → Set E
  sigmaRel : E → Set M
  piRel : M → Set C
  rhoRel : C → Set M
  kappa : S → Set C
  epsilon : S → Set E
  s : S
  hSelf2 : PostFixed2 piRel rhoRel (kappa s)
  hSMC : epsilon s ⊆ Hinge.T_prime alphaRel sigmaRel (epsilon s)
  hHingeNeeded : HingeNeeded piRel rhoRel sigmaRel kappa epsilon s
  hUnit : ∃ U, U ⊆ kappa s ∧ IrredUnit piRel rhoRel U ∧ NonSingleton U

/-- M1R-v2 §3.5 -/
theorem DC2.kappa_nonempty {M E C S : Type*} (d : DC2 M E C S) :
    (d.kappa d.s).Nonempty := by
  obtain ⟨U, hU, ⟨⟨x, hx⟩, -⟩, -⟩ := d.hUnit
  exact ⟨x, hU hx⟩

/-- M1R-v2 §3.5 -/
theorem DC2.beta_nonempty {M E C S : Type*} (d : DC2 M E C S) :
    (beta d.piRel d.rhoRel d.sigmaRel d.kappa d.epsilon d.s).Nonempty :=
  beta_nonempty_of_hingeNeeded d.hHingeNeeded d.hSelf2 d.kappa_nonempty

/-- M1R-v2 §3.5 -/
theorem DC2.act_nonempty {M E C S : Type*} (d : DC2 M E C S) :
    (Hinge.Act d.rhoRel d.sigmaRel d.kappa d.epsilon d.s).Nonempty :=
  act_nonempty_of_hingeNeeded d.hHingeNeeded d.hSelf2 d.kappa_nonempty

/-- M1R-v2 §3.5 -/
theorem DC2.unit_hinge_edge {M E C S : Type*} (d : DC2 M E C S) (U : Set C)
    (hU : U ⊆ d.kappa d.s) (hIrr : IrredUnit d.piRel d.rhoRel U) :
    HingeEdgeIn d.piRel d.rhoRel
      (Hinge.Act d.rhoRel d.sigmaRel d.kappa d.epsilon d.s) U :=
  hinge_edge_of_postfixed2 d.hHingeNeeded U hU hIrr.1 hIrr.2.1

/-! ### §3.6 -/

/-- M1R-v2 §3.6 -/
def DC2.toDC {M E C S : Type*} (d : DC2 M E C S) : DC M E C S where
  alphaRel := d.alphaRel
  sigmaRel := d.sigmaRel
  piRel := d.piRel
  rhoRel := d.rhoRel
  kappa := d.kappa
  epsilon := d.epsilon
  boundary := beta d.piRel d.rhoRel d.sigmaRel d.kappa d.epsilon d.s
  s := d.s
  hSelf := d.hSelf2.trans (phi2_subset_phi d.piRel d.rhoRel _)
  hSMC := d.hSMC
  hAct := d.act_nonempty
  hBound := by
    obtain ⟨c, hc⟩ := d.beta_nonempty
    exact ⟨c, beta_subset_kappa d.piRel d.rhoRel d.sigmaRel d.kappa d.epsilon d.s hc, hc⟩

/-- M1R-v2 §3.6 -/
theorem DC2.toDC_boundary {M E C S : Type*} (d : DC2 M E C S) :
    d.toDC.boundary = beta d.piRel d.rhoRel d.sigmaRel d.kappa d.epsilon d.s :=
  rfl

/-! ### §3.7 -/

/-- M1R-v2 §3.7: v1 の hBetaNeeded -/
def BetaNeeded {M E C S : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (sigmaRel : E → Set M) (kappa : S → Set C) (epsilon : S → Set E)
    (s : S) : Prop :=
  ¬ PostFixed2 piRel rhoRel (kappa s \ beta piRel rhoRel sigmaRel kappa epsilon s)

/-- M1R-v2 §3.7: 実装者報告の代案(κ∖β の中に自己維持部分がない) -/
def ResidualNoPostFixed {M E C S : Type*} (piRel : M → Set C) (rhoRel : C → Set M)
    (sigmaRel : E → Set M) (kappa : S → Set C) (epsilon : S → Set E)
    (s : S) : Prop :=
  ∀ V, V ⊆ kappa s \ beta piRel rhoRel sigmaRel kappa epsilon s →
    V.Nonempty → ¬ PostFixed2 piRel rhoRel V

/-- M1R-v2 §3.7: v1 の DC2 の全条件 -/
def V1Conditions {M E C S : Type*} (alphaRel : M → Set E) (sigmaRel : E → Set M)
    (piRel : M → Set C) (rhoRel : C → Set M) (kappa : S → Set C)
    (epsilon : S → Set E) (s : S) : Prop :=
  PostFixed2 piRel rhoRel (kappa s) ∧
  epsilon s ⊆ Hinge.T_prime alphaRel sigmaRel (epsilon s) ∧
  (Hinge.Act rhoRel sigmaRel kappa epsilon s).Nonempty ∧
  (beta piRel rhoRel sigmaRel kappa epsilon s).Nonempty ∧
  BetaNeeded piRel rhoRel sigmaRel kappa epsilon s ∧
  ∃ U, U ⊆ kappa s ∧ IrredUnit piRel rhoRel U ∧ NonSingleton U

/-- M1R-v2 §3.7 -/
theorem betaNeeded_of_hingeNeeded {M E C S : Type*} {piRel : M → Set C}
    {rhoRel : C → Set M} {sigmaRel : E → Set M} {kappa : S → Set C}
    {epsilon : S → Set E} {s : S}
    (h : HingeNeeded piRel rhoRel sigmaRel kappa epsilon s)
    (hres : (kappa s \ beta piRel rhoRel sigmaRel kappa epsilon s).Nonempty) :
    BetaNeeded piRel rhoRel sigmaRel kappa epsilon s := by
  intro hV
  refine h _ Set.sdiff_subset hres (postfixed2_rhoNH_of_no_edge piRel rhoRel _ _ hV ?_)
  rintro ⟨a, haAct, -, c, hca, hcK, hcB⟩
  exact hcB ⟨hcK, (aux_mem_pi_star _ _ _).2 ⟨a, haAct, hca⟩⟩

/-! ### §4.1 -/

namespace M1

inductive C | b | i
  deriving DecidableEq

inductive M | mx | mi
  deriving DecidableEq

inductive E | e
  deriving DecidableEq

def alphaR : M → Set E
  | .mx => {.e}
  | .mi => ∅

def sigmaR : E → Set M
  | .e => {.mx}

def piR : M → Set C
  | .mx => {.i}
  | .mi => {.b}

def rhoR : C → Set M
  | .b => {.mx}
  | .i => {.mi}

def kappa : Unit → Set C := fun _ => Set.univ

def eps : Unit → Set E := fun _ => Set.univ

@[simp] private theorem aux_exC (p : C → Prop) : (∃ x, p x) ↔ p .b ∨ p .i := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exM (p : M → Prop) : (∃ x, p x) ↔ p .mx ∨ p .mi := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exE (p : E → Prop) : (∃ x, p x) ↔ p .e := by
  constructor
  · rintro ⟨x, h⟩; cases x; exact h
  · intro h; exact ⟨_, h⟩

private theorem aux_act : Hinge.Act rhoR sigmaR kappa eps () = {.mx} := by
  ext m
  cases m <;> simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, rhoR, sigmaR, kappa, eps]

/-- M1R-v2 §4.1 -/
theorem beta_eq :
    beta piR rhoR sigmaR kappa eps () = {C.i} := by
  ext c
  cases c <;> simp [beta, aux_act, Closure.pi_star, piR, kappa]

private theorem aux_closed (V : Set C) (hV : PostFixed2 piR rhoR V) :
    (C.b ∈ V ↔ C.i ∈ V) := by
  constructor
  · intro h
    simpa [aux_mem_phi, aux_mem_rho_star, piR, rhoR] using (hV h).1
  · intro h
    simpa [aux_mem_phi, aux_mem_rho_star, piR, rhoR] using (hV h).1

private theorem aux_self : PostFixed2 piR rhoR (kappa ()) := by
  intro c _
  cases c <;>
    simp [Phi2, Psi, aux_mem_phi, aux_mem_rho_star, piR, rhoR, kappa, Set.Nonempty]

/-- M1R-v2 §4.1 -/
def dc2 : DC2 M E C Unit where
  alphaRel := alphaR
  sigmaRel := sigmaR
  piRel := piR
  rhoRel := rhoR
  kappa := kappa
  epsilon := eps
  s := ()
  hSelf2 := aux_self
  hSMC := by
    intro x _
    cases x
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, alphaR, sigmaR, eps]
  hHingeNeeded := by
    intro V _ ⟨x, hx⟩ hV
    have := hV hx
    rw [aux_act] at this
    cases x <;>
      simp [Phi2, Psi, aux_mem_phi, aux_mem_rho_star, rhoNH, piR, rhoR] at this
  hUnit := by
    refine ⟨kappa (), subset_rfl, ⟨⟨.b, trivial⟩, aux_self, ?_⟩,
      ⟨.b, trivial, .i, trivial, by decide⟩⟩
    intro V _ ⟨x, hx⟩ hV
    have hcl := aux_closed V hV
    have hb : C.b ∈ V := by
      cases x
      · exact hx
      · exact hcl.2 hx
    ext c
    cases c <;> simp [kappa, hb, hcl.1 hb]

end M1

/-! ### §4.2 -/

namespace M2

inductive C | a | b | w
  deriving DecidableEq

inductive M | m1 | m2
  deriving DecidableEq

inductive E | e
  deriving DecidableEq

def alphaR : M → Set E
  | .m1 => {.e}
  | .m2 => ∅

def sigmaR : E → Set M
  | .e => {.m1}

def piR : M → Set C
  | .m1 => {.b, .w}
  | .m2 => {.a}

def rhoR : C → Set M
  | .a => {.m1}
  | .b => {.m2}
  | .w => ∅

def kappa : Unit → Set C := fun _ => Set.univ

def eps : Unit → Set E := fun _ => Set.univ

/-- M1R-v2 §4.2 -/
def boundary : Set C := {.b}

@[simp] private theorem aux_exC (p : C → Prop) :
    (∃ x, p x) ↔ p .a ∨ p .b ∨ p .w := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exM (p : M → Prop) : (∃ x, p x) ↔ p .m1 ∨ p .m2 := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exE (p : E → Prop) : (∃ x, p x) ↔ p .e := by
  constructor
  · rintro ⟨x, h⟩; cases x; exact h
  · intro h; exact ⟨_, h⟩

/-- M1R-v2 §4.2 -/
def dc : DC M E C Unit where
  alphaRel := alphaR
  sigmaRel := sigmaR
  piRel := piR
  rhoRel := rhoR
  kappa := kappa
  epsilon := eps
  boundary := boundary
  s := ()
  hSelf := by
    intro c _
    cases c <;> simp [aux_mem_phi, aux_mem_rho_star, piR, rhoR, kappa]
  hSMC := by
    intro x _
    cases x
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, alphaR, sigmaR, eps]
  hAct := ⟨.m1, by
    simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, rhoR, sigmaR, kappa, eps]⟩
  hBound := ⟨.b, trivial, rfl⟩

/-- M1R-v2 §4.2 -/
theorem not_self2 : ¬ PostFixed2 piR rhoR (kappa ()) := by
  intro h
  obtain ⟨-, m, hm, -⟩ := h (show C.w ∈ kappa () from trivial)
  exact hm

end M2

/-! ### §4.3 -/

namespace M3

inductive C | a1 | a2 | b1 | b2
  deriving DecidableEq

inductive M | m1 | m2 | n1 | n2
  deriving DecidableEq

inductive E | e
  deriving DecidableEq

def alphaR : M → Set E
  | .m1 => {.e}
  | _ => ∅

def sigmaR : E → Set M
  | .e => {.m1}

def piR : M → Set C
  | .m1 => {.a2}
  | .m2 => {.a1}
  | .n1 => {.b2}
  | .n2 => {.b1}

def rhoR : C → Set M
  | .a1 => {.m1}
  | .a2 => {.m2}
  | .b1 => {.n1}
  | .b2 => {.n2}

def kappa : Unit → Set C := fun _ => Set.univ

def eps : Unit → Set E := fun _ => Set.univ

@[simp] private theorem aux_exC (p : C → Prop) :
    (∃ x, p x) ↔ p .a1 ∨ p .a2 ∨ p .b1 ∨ p .b2 := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h | h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exM (p : M → Prop) :
    (∃ x, p x) ↔ p .m1 ∨ p .m2 ∨ p .n1 ∨ p .n2 := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h | h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exE (p : E → Prop) : (∃ x, p x) ↔ p .e := by
  constructor
  · rintro ⟨x, h⟩; cases x; exact h
  · intro h; exact ⟨_, h⟩

private theorem aux_act : Hinge.Act rhoR sigmaR kappa eps () = {.m1} := by
  ext m
  cases m <;> simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, rhoR, sigmaR, kappa, eps]

private theorem aux_beta : beta piR rhoR sigmaR kappa eps () = {.a2} := by
  ext c
  cases c <;> simp [beta, aux_act, Closure.pi_star, piR, kappa]

private theorem aux_closed (V : Set C) (hV : PostFixed2 piR rhoR V) :
    (C.a1 ∈ V → C.a2 ∈ V) ∧ (C.b1 ∈ V ↔ C.b2 ∈ V) := by
  refine ⟨fun h => ?_, fun h => ?_, fun h => ?_⟩ <;>
    simpa [aux_mem_phi, aux_mem_rho_star, piR, rhoR] using (hV h).1

private theorem aux_unitB_post : PostFixed2 piR rhoR ({C.b1, C.b2} : Set C) := by
  intro c hc
  simp only [Set.mem_insert_iff, Set.mem_singleton_iff] at hc
  rcases hc with rfl | rfl <;>
    simp [Phi2, Psi, aux_mem_phi, aux_mem_rho_star, piR, rhoR, Set.Nonempty]

/-- M1R-v2 §4.3 -/
theorem unitB_irred :
    IrredUnit piR rhoR ({C.b1, C.b2} : Set C) := by
  refine ⟨⟨.b1, by simp⟩, aux_unitB_post, ?_⟩
  intro V hVU ⟨x, hx⟩ hV
  have hcl := (aux_closed V hV).2
  have hb1 : C.b1 ∈ V := by
    cases x
    · simpa using hVU hx
    · simpa using hVU hx
    · exact hx
    · exact hcl.2 hx
  ext c
  constructor
  · exact fun hc => hVU hc
  · intro hc
    simp only [Set.mem_insert_iff, Set.mem_singleton_iff] at hc
    rcases hc with rfl | rfl
    · exact hb1
    · exact hcl.1 hb1

/-- M1R-v2 §4.3 -/
theorem v1_holds :
    V1Conditions alphaR sigmaR piR rhoR kappa eps () := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro c _
    cases c <;>
      simp [Phi2, Psi, aux_mem_phi, aux_mem_rho_star, piR, rhoR, kappa, Set.Nonempty]
  · intro x _
    cases x
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, alphaR, sigmaR, eps]
  · rw [aux_act]; exact ⟨.m1, rfl⟩
  · rw [aux_beta]; exact ⟨.a2, rfl⟩
  · unfold BetaNeeded
    rw [aux_beta]
    intro hV
    have := (aux_closed _ hV).1 (by simp [kappa])
    simp at this
  · exact ⟨{C.b1, C.b2}, fun _ _ => trivial, unitB_irred,
      ⟨.b1, by simp, .b2, by simp, by decide⟩⟩

/-- M1R-v2 §4.3 -/
theorem not_hingeNeeded :
    ¬ HingeNeeded piR rhoR sigmaR kappa eps () := by
  intro h
  refine h {C.b1, C.b2} (fun _ _ => trivial) ⟨.b1, by simp⟩ ?_
  rw [aux_act]
  intro c hc
  simp only [Set.mem_insert_iff, Set.mem_singleton_iff] at hc
  rcases hc with rfl | rfl <;>
    simp [Phi2, Psi, aux_mem_phi, aux_mem_rho_star, rhoNH, piR, rhoR, Set.Nonempty]

/-- M1R-v2 §4.3 -/
theorem unitB_disjoint :
    Disjoint ({M3.C.b1, M3.C.b2} : Set M3.C)
      (beta M3.piR M3.rhoR M3.sigmaR M3.kappa M3.eps ()) := by
  rw [aux_beta]
  simp

end M3

/-! ### §4.4 -/

namespace M4

inductive C | a1 | a2 | b1 | b2
  deriving DecidableEq

inductive M | m1 | m2 | n1 | n2
  deriving DecidableEq

inductive E | e
  deriving DecidableEq

def alphaR : M → Set E
  | .m1 => {.e}
  | _ => ∅

def sigmaR : E → Set M
  | .e => {.m1}

def piR : M → Set C
  | .m1 => {.a2, .b1}
  | .m2 => {.a1}
  | .n1 => {.b2}
  | .n2 => {.b1}

def rhoR : C → Set M
  | .a1 => {.m1}
  | .a2 => {.m2}
  | .b1 => {.n1}
  | .b2 => {.n2}

def kappa : Unit → Set C := fun _ => Set.univ

def eps : Unit → Set E := fun _ => Set.univ

@[simp] private theorem aux_exC (p : C → Prop) :
    (∃ x, p x) ↔ p .a1 ∨ p .a2 ∨ p .b1 ∨ p .b2 := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h | h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exM (p : M → Prop) :
    (∃ x, p x) ↔ p .m1 ∨ p .m2 ∨ p .n1 ∨ p .n2 := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h | h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exE (p : E → Prop) : (∃ x, p x) ↔ p .e := by
  constructor
  · rintro ⟨x, h⟩; cases x; exact h
  · intro h; exact ⟨_, h⟩

private theorem aux_act : Hinge.Act rhoR sigmaR kappa eps () = {.m1} := by
  ext m
  cases m <;> simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, rhoR, sigmaR, kappa, eps]

private theorem aux_beta : beta piR rhoR sigmaR kappa eps () = {.a2, .b1} := by
  ext c
  cases c <;> simp [beta, aux_act, Closure.pi_star, piR, kappa]

/-- M1R-v2 §4.4 -/
theorem residual_holds :
    ResidualNoPostFixed piR rhoR sigmaR kappa eps () := by
  intro V hVsub ⟨x, hx⟩ hV
  rw [aux_beta] at hVsub
  have ha2 : C.a2 ∉ V := fun h => (hVsub h).2 (by simp)
  have hb1 : C.b1 ∉ V := fun h => (hVsub h).2 (by simp)
  cases x
  · have := (hV hx).1
    simp [aux_mem_phi, aux_mem_rho_star, piR, rhoR, ha2, hb1] at this
  · exact ha2 hx
  · exact hb1 hx
  · have := (hV hx).1
    simp [aux_mem_phi, aux_mem_rho_star, piR, rhoR, ha2, hb1] at this

/-- M1R-v2 §4.4 -/
theorem not_hingeNeeded :
    ¬ HingeNeeded piR rhoR sigmaR kappa eps () := by
  intro h
  refine h {C.b1, C.b2} (fun _ _ => trivial) ⟨.b1, by simp⟩ ?_
  rw [aux_act]
  intro c hc
  simp only [Set.mem_insert_iff, Set.mem_singleton_iff] at hc
  rcases hc with rfl | rfl <;>
    simp [Phi2, Psi, aux_mem_phi, aux_mem_rho_star, rhoNH, piR, rhoR, Set.Nonempty]

end M4

/-! ### §4.5 -/

namespace M5

inductive C | b | i
  deriving DecidableEq

inductive M | mx | my
  deriving DecidableEq

inductive E | e
  deriving DecidableEq

def alphaR : M → Set E
  | .mx => {.e}
  | .my => {.e}

def sigmaR : E → Set M
  | .e => {.mx, .my}

def piR : M → Set C
  | .mx => {.i}
  | .my => {.b}

def rhoR : C → Set M
  | .b => {.mx}
  | .i => {.my}

def kappa : Unit → Set C := fun _ => Set.univ

def eps : Unit → Set E := fun _ => Set.univ

@[simp] private theorem aux_exC (p : C → Prop) : (∃ x, p x) ↔ p .b ∨ p .i := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exM (p : M → Prop) : (∃ x, p x) ↔ p .mx ∨ p .my := by
  constructor
  · rintro ⟨x, h⟩; cases x <;> simp [h]
  · rintro (h | h) <;> exact ⟨_, h⟩

@[simp] private theorem aux_exE (p : E → Prop) : (∃ x, p x) ↔ p .e := by
  constructor
  · rintro ⟨x, h⟩; cases x; exact h
  · intro h; exact ⟨_, h⟩

private theorem aux_act : Hinge.Act rhoR sigmaR kappa eps () = {.mx, .my} := by
  ext m
  cases m <;> simp [Hinge.Act, Closure.rho_star, Adj.sigma_star, rhoR, sigmaR, kappa, eps]

/-- M1R-v2 §4.5 -/
theorem beta_eq_kappa :
    beta piR rhoR sigmaR kappa eps () = kappa () := by
  ext c
  cases c <;> simp [beta, aux_act, Closure.pi_star, piR, kappa]

private theorem aux_closed (V : Set C) (hV : PostFixed2 piR rhoR V) :
    (C.b ∈ V ↔ C.i ∈ V) := by
  constructor
  · intro h
    simpa [aux_mem_phi, aux_mem_rho_star, piR, rhoR] using (hV h).1
  · intro h
    simpa [aux_mem_phi, aux_mem_rho_star, piR, rhoR] using (hV h).1

private theorem aux_self : PostFixed2 piR rhoR (kappa ()) := by
  intro c _
  cases c <;>
    simp [Phi2, Psi, aux_mem_phi, aux_mem_rho_star, piR, rhoR, kappa, Set.Nonempty]

/-- M1R-v2 §4.5 -/
def dc2 : DC2 M E C Unit where
  alphaRel := alphaR
  sigmaRel := sigmaR
  piRel := piR
  rhoRel := rhoR
  kappa := kappa
  epsilon := eps
  s := ()
  hSelf2 := aux_self
  hSMC := by
    intro x _
    cases x
    simp [Hinge.T_prime, Adj.alpha_star, Adj.sigma_star, alphaR, sigmaR, eps]
  hHingeNeeded := by
    intro V _ ⟨x, hx⟩ hV
    have := hV hx
    rw [aux_act] at this
    cases x <;>
      simp [Phi2, Psi, rhoNH, piR, rhoR] at this
  hUnit := by
    refine ⟨kappa (), subset_rfl, ⟨⟨.b, trivial⟩, aux_self, ?_⟩,
      ⟨.b, trivial, .i, trivial, by decide⟩⟩
    intro V _ ⟨x, hx⟩ hV
    have hcl := aux_closed V hV
    have hb : C.b ∈ V := by
      cases x
      · exact hx
      · exact hcl.2 hx
    ext c
    cases c <;> simp [kappa, hb, hcl.1 hb]

/-- M1R-v2 §4.5 -/
theorem not_betaNeeded :
    ¬ BetaNeeded piR rhoR sigmaR kappa eps () := by
  intro h
  apply h
  rw [beta_eq_kappa, Set.sdiff_self]
  exact Set.empty_subset _

end M5

end ERIEC.M1R

#print axioms ERIEC.M1R.Psi
#print axioms ERIEC.M1R.Phi2
#print axioms ERIEC.M1R.PostFixed2
#print axioms ERIEC.M1R.psi_mono
#print axioms ERIEC.M1R.phi2_mono
#print axioms ERIEC.M1R.phi2_subset_phi
#print axioms ERIEC.M1R.nu_phi2_subset_nu_phi
#print axioms ERIEC.M1R.nu_phi2_postfixed
#print axioms ERIEC.M1R.IrredUnit
#print axioms ERIEC.M1R.NonSingleton
#print axioms ERIEC.M1R.beta
#print axioms ERIEC.M1R.beta_subset_kappa
#print axioms ERIEC.M1R.beta_subset_phi
#print axioms ERIEC.M1R.rhoNH
#print axioms ERIEC.M1R.HingeEdgeIn
#print axioms ERIEC.M1R.HingeNeeded
#print axioms ERIEC.M1R.postfixed2_of_rhoNH
#print axioms ERIEC.M1R.postfixed2_rhoNH_of_no_edge
#print axioms ERIEC.M1R.hinge_edge_of_postfixed2
#print axioms ERIEC.M1R.beta_nonempty_of_hingeNeeded
#print axioms ERIEC.M1R.act_nonempty_of_hingeNeeded
#print axioms ERIEC.M1R.DC2.kappa_nonempty
#print axioms ERIEC.M1R.DC2.beta_nonempty
#print axioms ERIEC.M1R.DC2.act_nonempty
#print axioms ERIEC.M1R.DC2.unit_hinge_edge
#print axioms ERIEC.M1R.DC2.toDC
#print axioms ERIEC.M1R.DC2.toDC_boundary
#print axioms ERIEC.M1R.BetaNeeded
#print axioms ERIEC.M1R.ResidualNoPostFixed
#print axioms ERIEC.M1R.V1Conditions
#print axioms ERIEC.M1R.betaNeeded_of_hingeNeeded
#print axioms ERIEC.M1R.M1.alphaR
#print axioms ERIEC.M1R.M1.sigmaR
#print axioms ERIEC.M1R.M1.piR
#print axioms ERIEC.M1R.M1.rhoR
#print axioms ERIEC.M1R.M1.kappa
#print axioms ERIEC.M1R.M1.eps
#print axioms ERIEC.M1R.M1.dc2
#print axioms ERIEC.M1R.M1.beta_eq
#print axioms ERIEC.M1R.M2.alphaR
#print axioms ERIEC.M1R.M2.sigmaR
#print axioms ERIEC.M1R.M2.piR
#print axioms ERIEC.M1R.M2.rhoR
#print axioms ERIEC.M1R.M2.kappa
#print axioms ERIEC.M1R.M2.eps
#print axioms ERIEC.M1R.M2.boundary
#print axioms ERIEC.M1R.M2.dc
#print axioms ERIEC.M1R.M2.not_self2
#print axioms ERIEC.M1R.M3.alphaR
#print axioms ERIEC.M1R.M3.sigmaR
#print axioms ERIEC.M1R.M3.piR
#print axioms ERIEC.M1R.M3.rhoR
#print axioms ERIEC.M1R.M3.kappa
#print axioms ERIEC.M1R.M3.eps
#print axioms ERIEC.M1R.M3.v1_holds
#print axioms ERIEC.M1R.M3.not_hingeNeeded
#print axioms ERIEC.M1R.M3.unitB_irred
#print axioms ERIEC.M1R.M3.unitB_disjoint
#print axioms ERIEC.M1R.M4.alphaR
#print axioms ERIEC.M1R.M4.sigmaR
#print axioms ERIEC.M1R.M4.piR
#print axioms ERIEC.M1R.M4.rhoR
#print axioms ERIEC.M1R.M4.kappa
#print axioms ERIEC.M1R.M4.eps
#print axioms ERIEC.M1R.M4.residual_holds
#print axioms ERIEC.M1R.M4.not_hingeNeeded
#print axioms ERIEC.M1R.M5.alphaR
#print axioms ERIEC.M1R.M5.sigmaR
#print axioms ERIEC.M1R.M5.piR
#print axioms ERIEC.M1R.M5.rhoR
#print axioms ERIEC.M1R.M5.kappa
#print axioms ERIEC.M1R.M5.eps
#print axioms ERIEC.M1R.M5.dc2
#print axioms ERIEC.M1R.M5.beta_eq_kappa
#print axioms ERIEC.M1R.M5.not_betaNeeded
