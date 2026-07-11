namespace ERIEC
namespace RefModel

inductive RefState where
  | s0
  | s1
  | s2
  deriving DecidableEq

def next : RefState → RefState
  | .s0 => .s1
  | .s1 => .s2
  | .s2 => .s2

theorem reference_models :
    next RefState.s0 = RefState.s1 ∧
    next RefState.s1 = RefState.s2 ∧
    next RefState.s2 = RefState.s2 := by
  decide

end RefModel
end ERIEC
