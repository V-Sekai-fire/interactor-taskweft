import Lake
open Lake DSL

package «taskweft-grafcet-static» where
  leanOptions := #[⟨`autoImplicit, false⟩]

lean_lib TaskweftGrafcetStatic where
  roots := #[`TaskweftGrafcetStatic, `TaskweftGrafcetStatic.Analyse]
  precompileModules := true

@[default_target]
lean_exe grafcet_static where
  root := `Main
