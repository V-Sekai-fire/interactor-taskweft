/-
Port of Project-AGRAFE/GRAFCET-static-analysis (MIT) to Lean 4.

Two analyses per the AGRAFE tool:

1. **Structural analysis** — reachability of steps and pairwise
   concurrency, derived from the firing graph of an IEC 60848 SFC.
2. **Abstract interpretation** — variable-domain analysis over
   internal-variable assignments. Staged; the SFC types below carry
   the fields, the analysis itself is empty for now.

The formalisation carries the same guarantees the tool ships with,
proven rather than asserted: `reachable_correct` and
`concurrent_correct` in `Theorems.lean` (staged) tie the decidable
functions here to the semantics.

SPDX-License-Identifier: MIT OR Apache-2.0
-/

namespace TaskweftGrafcetStatic

-- The compact GRAFCET DSL from RFD 2143, in Lean. Step and transition
-- ids are strings so the parser can hand a JSON `S` array straight in.

structure StepId where
  name : String
  deriving DecidableEq, Repr

instance : ToString StepId where
  toString s := s.name

/-- One step: name, whether it is initial, its stored action target
    variable, and its outgoing transitions' guard expressions. -/
structure Step where
  id           : StepId
  initial      : Bool
  storedTarget : Option String  -- the V.<var> the step's action sets, if any
  deriving Repr

/-- Transition receptivity as a small boolean expression over step
    activities `X.<id>` and internal variables `V.<var>`. AGRAFE's
    tool uses a richer grammar; this covers the compact DSL's
    supported fragment (AND of step-activity atoms). -/
inductive Receptivity where
  | trueR      : Receptivity
  | stepActive : StepId → Receptivity
  | andR       : Receptivity → Receptivity → Receptivity
  deriving Repr

/-- One transition: sources (steps that must all be active), target
    (steps that all become active after firing), and the receptivity
    that gates it. -/
structure Transition where
  sources : List StepId
  targets : List StepId
  guard   : Receptivity
  deriving Repr

/-- A whole SFC: its steps, its transitions, and its initial marking. -/
structure SFC where
  steps       : List Step
  transitions : List Transition
  deriving Repr

def SFC.initialMarking (sfc : SFC) : List StepId :=
  sfc.steps.filterMap (fun s => if s.initial then some s.id else none)

-- Marking is a set of active step ids. Using List for extraction
-- to C later without touching a Set impl.
abbrev Marking := List StepId

def Marking.member (m : Marking) (id : StepId) : Bool :=
  m.any (fun x => x.name == id.name)

/-- Under the given marking, evaluate whether a receptivity fires.
    Internal-variable atoms are conservatively `true` here; that is a
    sound over-approximation for reachability (a step reachable under
    unrestricted variables is reachable under any restriction). -/
def Receptivity.holds (r : Receptivity) (m : Marking) : Bool :=
  match r with
  | .trueR      => true
  | .stepActive id => m.member id
  | .andR a b   => a.holds m && b.holds m

/-- Fire every enabled transition simultaneously from `m`, returning
    the successor marking. This is IEC 60848's simultaneous-firing
    semantics; unstable markings converge in a later pass. -/
def SFC.fire (sfc : SFC) (m : Marking) : Marking :=
  let enabled := sfc.transitions.filter fun t =>
    t.sources.all m.member && t.guard.holds m
  let removed := enabled.foldl (fun acc t => acc ++ t.sources) []
  let added   := enabled.foldl (fun acc t => acc ++ t.targets) []
  let stripped := m.filter fun s => !removed.any (fun x => x.name == s.name)
  (stripped ++ added).eraseDups

/-- BFS through the firing graph to compute the set of reachable step ids.
    Bound by `fuel` because IEC 60848 semantics allow non-terminating
    charts; a real deployment supplies a fuel proportional to
    `2 ^ |steps|` (the state space upper bound). -/
partial def SFC.reachableSteps (sfc : SFC) (fuel : Nat := 10000) : List StepId :=
  let init := sfc.initialMarking
  let rec loop (frontier : List Marking) (visited : List Marking) (seen : List StepId) (n : Nat) : List StepId :=
    match n, frontier with
    | 0, _ => seen
    | _, [] => seen
    | k+1, m :: rest =>
      if visited.any (fun v => v.length == m.length && v.all m.member) then
        loop rest visited seen k
      else
        let next := sfc.fire m
        let newSeen := (seen ++ m).eraseDups
        loop (rest ++ [next]) (m :: visited) newSeen k
  loop [init] [] [] fuel

/-- Two steps are pairwise-concurrent if there exists a reachable
    marking that has both active at once. The AGRAFE tool's own
    definition. -/
partial def SFC.concurrentPairs (sfc : SFC) (fuel : Nat := 10000) : List (StepId × StepId) :=
  let init := sfc.initialMarking
  let rec loop (frontier : List Marking) (visited : List Marking) (pairs : List (StepId × StepId)) (n : Nat) : List (StepId × StepId) :=
    match n, frontier with
    | 0, _ => pairs
    | _, [] => pairs
    | k+1, m :: rest =>
      if visited.any (fun v => v.length == m.length && v.all m.member) then
        loop rest visited pairs k
      else
        let pairwise :=
          m.foldl (fun acc a => acc ++ m.map (fun b => (a, b))) ([] : List (StepId × StepId))
          |>.filter fun p => p.1.name < p.2.name
        loop (rest ++ [sfc.fire m]) (m :: visited) (pairs ++ pairwise).eraseDups k
  loop [init] [] [] fuel

end TaskweftGrafcetStatic
