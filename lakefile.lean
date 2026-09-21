import Lake
open Lake DSL

package «taskweft-fbd-static» where
  leanOptions := #[⟨`autoImplicit, false⟩]

lean_lib TaskweftFbdStatic where
  roots := #[`TaskweftFbdStatic, `TaskweftFbdStatic.Analyse]
  precompileModules := true

@[default_target]
lean_exe fbd_static where
  root := `Main
