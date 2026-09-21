/-
Smoke test: build the blocks_get_or fixture (RFD 2143's OR-divergence
worked example) and print its reachable steps + concurrent pairs.

SPDX-License-Identifier: MIT OR Apache-2.0
-/
import TaskweftFbdStatic

open TaskweftFbdStatic

def blocksGetOr : SFC :=
  let init := { id := ⟨"init"⟩, initial := true, storedTarget := none : Step }
  let find := { id := ⟨"find"⟩, initial := false, storedTarget := some "found" : Step }
  let pickup := { id := ⟨"pickup_from_table"⟩, initial := false, storedTarget := some "picked" : Step }
  let unstack := { id := ⟨"unstack"⟩, initial := false, storedTarget := some "unstacked" : Step }
  let markDone := { id := ⟨"mark_done"⟩, initial := false, storedTarget := some "done" : Step }
  {
    steps := [init, find, pickup, unstack, markDone],
    transitions := [
      { sources := [⟨"init"⟩], targets := [⟨"find"⟩], guard := .trueR },
      { sources := [⟨"find"⟩], targets := [⟨"pickup_from_table"⟩], guard := .stepActive ⟨"find"⟩ },
      { sources := [⟨"find"⟩], targets := [⟨"unstack"⟩], guard := .stepActive ⟨"find"⟩ },
      { sources := [⟨"pickup_from_table"⟩], targets := [⟨"mark_done"⟩], guard := .trueR },
      { sources := [⟨"unstack"⟩], targets := [⟨"mark_done"⟩], guard := .trueR }
    ]
  }

def main : IO Unit := do
  let reachable := blocksGetOr.reachableSteps
  IO.println s!"reachable: {reachable.map toString}"
  let pairs := blocksGetOr.concurrentPairs
  IO.println s!"concurrent pairs: {pairs.map (fun p => (p.1.name, p.2.name))}"
