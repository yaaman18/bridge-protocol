import Mathlib.Data.Set.Basic

namespace ERIEC

namespace Guard


structure Reachability (Obj : Type*) where
  reaches : Obj → Obj → Prop

def HasTStar {Obj : Type*} (R : Reachability Obj) : Prop :=
  ∃ terminal, ∀ source, R.reaches source terminal

def NoTStar {Obj : Type*} (R : Reachability Obj) : Prop :=
  ¬ HasTStar R

theorem hasTStar_iff_terminal {Obj : Type*} (R : Reachability Obj) :
    HasTStar R ↔ ∃ terminal, ∀ source, R.reaches source terminal :=
  Iff.rfl

theorem noTStar_to_noT {Obj : Type*} {R : Reachability Obj}
    (h : NoTStar R) : ¬ ∃ terminal, ∀ source, R.reaches source terminal :=
  h

def M4 {Obj : Type*} (R : Reachability Obj) : Prop := NoTStar R

def TraceSafe {Sys Trace : Type*} (prot : Sys → Trace) (mutation : Sys → Sys) : Prop :=
  ∀ system, prot (mutation system) = prot system

def M4Safe {Sys : Type*} (property : Sys → Prop) (mutation : Sys → Sys) : Prop :=
  ∀ system, property (mutation system) ↔ property system

theorem traceSafe_to_M4Safe {Sys Trace : Type*}
    (prot : Sys → Trace) (mutation : Sys → Sys) (predicate : Trace → Prop)
    (hsafe : TraceSafe prot mutation) :
    M4Safe (fun system => predicate (prot system)) mutation := by
  intro system
  change predicate (prot (mutation system)) ↔ predicate (prot system)
  rw [hsafe system]

def kleisli {A B C : Type*} (first : A → Option B) (second : B → Option C) :
    A → Option C :=
  fun input => (first input).bind second

end Guard

end ERIEC
