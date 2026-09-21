/-
JSON I/O for the analyser. Parses the compact FBD profile (RFD 2143)
into `SFC`, runs both structural analyses, and encodes the result.

`@[export analyse_sfc]` exposes it under the plain C name `analyse_sfc`;
the C bridge in `c_src/fbd_static_bridge.c` wraps the string
marshaling and refcount management.

SPDX-License-Identifier: MIT OR Apache-2.0
-/
import Lean.Data.Json
import TaskweftFbdStatic

namespace TaskweftFbdStatic
open Lean

/-- Extract the `S` array from a parsed compact FBD JSON and build
    an `SFC` from it. This is intentionally forgiving; a malformed row
    is skipped, so a partial chart still analyses. -/
def sfcFromJson (json : Json) : SFC := Id.run do
  let arr := (json.getObjValAs? (Array Json) "S").toOption.getD #[]
  let mut steps : List Step := []
  let mut trans : List Transition := []
  let mut lastId : Option StepId := none
  let mut initial : Bool := true
  for row in arr do
    let items := (row.getArr?).toOption.getD #[]
    if items.size == 0 then continue
    let head := (items[0]!.getStr?).toOption.getD ""
    match head with
    | "^" =>
      let s : Step := { id := ⟨"__init"⟩, initial := true, storedTarget := none }
      steps := steps ++ [s]
      lastId := some ⟨"__init"⟩
      initial := false
    | "&>" | "|>" =>
      -- After a divergence, transitions from lastId to each named child
      let parent := lastId.getD ⟨""⟩
      for i in [1:items.size] do
        let child := (items[i]!.getStr?).toOption.getD ""
        if child != "" then
          trans := trans ++ [{ sources := [parent],
                               targets := [⟨child⟩], guard := .trueR }]
    | "&<" | "|<" =>
      -- next ordinary row is the merged successor; that row's own
      -- transition wiring will pick up its predecessors from `sources`,
      -- so nothing to record here.
      pure ()
    | _ =>
      -- ordinary step row [name, when, do, t]
      let name := head
      let whenStr := if items.size > 1
                     then (items[1]!.getStr?).toOption.getD "" else ""
      let s : Step := { id := ⟨name⟩, initial := false, storedTarget := none }
      steps := steps ++ [s]
      -- one transition from lastId (implicit sequential link) into name,
      -- guarded by `whenStr` parsed as an AND of X.<step> atoms
      let guard : Receptivity :=
        if whenStr == "" then
          .trueR
        else
          let atoms := whenStr.splitOn "&" |>.map (fun s => s.trimAscii.toString)
          let firsts := atoms.filterMap fun a =>
            if a.startsWith "X." then some ⟨(a.drop 2).toString⟩ else none
          match firsts with
          | []      => .trueR
          | [x]     => .stepActive x
          | x :: xs => xs.foldl (init := Receptivity.stepActive x)
                       (fun acc y => .andR acc (.stepActive y))
      match lastId with
      | some p =>
        trans := trans ++ [{ sources := [p], targets := [⟨name⟩], guard := guard }]
      | none => ()
      lastId := some ⟨name⟩
  return { steps := steps, transitions := trans }

/-- Encode the analysis result. -/
def analysisJson (sfc : SFC) : Json :=
  let reachable := sfc.reachableSteps
  let pairs := sfc.concurrentPairs
  Json.mkObj [
    ("reachable", Json.arr (reachable.map (fun s => Json.str s.name)).toArray),
    ("concurrent_pairs",
      Json.arr (pairs.map (fun p =>
        Json.arr #[Json.str p.1.name, Json.str p.2.name])).toArray)
  ]

/-- The exported analyser: JSON string in, JSON string out. -/
@[export analyse_sfc]
def analyseSFC (input : String) : String :=
  match Json.parse input with
  | .error msg =>
      (Json.mkObj [("error", Json.str "parse"),
                   ("reason", Json.str msg)]).compress
  | .ok j =>
      (analysisJson (sfcFromJson j)).compress

end TaskweftFbdStatic
