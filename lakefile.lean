import Lake
open Lake DSL

package ERIEC where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

@[default_target]
lean_lib ERIEC where
  srcDir := "formal"

lean_exe eriec_certified_artifact where
  root := `ERIEC.CertifiedArtifact
  srcDir := "formal"
