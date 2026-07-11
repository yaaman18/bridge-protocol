import Mathlib.Data.Bool.Basic

namespace ERIEC

namespace Markers

structure FMMarkers where
  fm1_global : Bool
  fm2_sensorimotor : Bool
  fm3_selfMonitoring : Bool
  fm4_world : Bool
  deriving DecidableEq

inductive FunctionalClass where
  | consciousMarker
  | blindsightAnalog
  | nonconsciousMarker
  deriving DecidableEq

def classify (markers : FMMarkers) : FunctionalClass :=
  if markers.fm1_global && markers.fm2_sensorimotor &&
      markers.fm3_selfMonitoring && markers.fm4_world then
    .consciousMarker
  else if markers.fm1_global && markers.fm4_world &&
      (!markers.fm2_sensorimotor || !markers.fm3_selfMonitoring) then
    .blindsightAnalog
  else
    .nonconsciousMarker

def Conscious (markers : FMMarkers) : Prop :=
  markers.fm1_global = true ∧ markers.fm2_sensorimotor = true ∧
    markers.fm3_selfMonitoring = true ∧ markers.fm4_world = true

def Blind (markers : FMMarkers) : Prop :=
  markers.fm1_global = true ∧ markers.fm4_world = true ∧
    (markers.fm2_sensorimotor = false ∨ markers.fm3_selfMonitoring = false)

theorem conscious_classification {markers : FMMarkers} (h : Conscious markers) :
    classify markers = .consciousMarker := by
  rcases h with ⟨h1, h2, h3, h4⟩
  simp [classify, h1, h2, h3, h4]

theorem blind_classification {markers : FMMarkers} (h : Blind markers) :
    classify markers = .blindsightAnalog := by
  rcases h with ⟨h1, h4, h2 | h3⟩
  · simp [classify, h1, h2, h4]
  · simp [classify, h1, h3, h4]

end Markers

end ERIEC
