# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

# An issue tracker's dependency graph, as a planning domain.
#
# An issue closes when every issue that blocks it is closed. That single rule
# is what a tracker's "ready" list computes, so a plan over this domain is an
# order the tracker must agree with, and a graph it would deadlock on has no
# plan at all. issue_graph_cycle is the same shape with one edge reversed and
# is required to be unplannable.
#
# THE ORDER IS THE PLANNER'S TO FIND. A todo_list is a sequence, so naming the
# issues in it fixes an order the preconditions may forbid - listing them
# alphabetically here yields no_plan, because b is reached before the a that
# blocks it. close_all instead offers every still-open issue as an alternative
# and recurses, which is what makes the derived order evidence rather than
# something restated.
#
# The shape is taken from a real chain: two issues block a third, and one of
# those is itself blocked, so no single edge decides the answer.

defmodule IssueGraph do
  use Taskweft.DSL

  @name "issue_graph"

  @variables %{
    open: %{type: :bool, init: %{a: true, b: true, c: true, d: true}}
  }

  @actions %{
    a_close_a: %{
      params: [],
      body: [
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/a"}, b: true}},
        %{pointer_set: "/open/a", value: false}
      ]
    },
    a_close_b: %{
      params: [],
      body: [
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/a"}, b: false}},
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/b"}, b: true}},
        %{pointer_set: "/open/b", value: false}
      ]
    },
    a_close_c: %{
      params: [],
      body: [
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/c"}, b: true}},
        %{pointer_set: "/open/c", value: false}
      ]
    },
    a_close_d: %{
      params: [],
      body: [
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/b"}, b: false}},
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/c"}, b: false}},
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/d"}, b: true}},
        %{pointer_set: "/open/d", value: false}
      ]
    }
  }

  @methods %{
    close_all: %{
      params: [],
      alternatives: [
        %{
          name: :all_closed,
          check: [
            %{eval: %{type: "math/eq", a: %{pointer_get: "/open/a"}, b: false}},
            %{eval: %{type: "math/eq", a: %{pointer_get: "/open/b"}, b: false}},
            %{eval: %{type: "math/eq", a: %{pointer_get: "/open/c"}, b: false}},
            %{eval: %{type: "math/eq", a: %{pointer_get: "/open/d"}, b: false}}
          ],
          subtasks: []
        },
        %{
          name: :close_a,
          check: [%{eval: %{type: "math/eq", a: %{pointer_get: "/open/a"}, b: true}}],
          subtasks: [["a_close_a"], ["close_all"]]
        },
        %{
          name: :close_b,
          check: [%{eval: %{type: "math/eq", a: %{pointer_get: "/open/b"}, b: true}}],
          subtasks: [["a_close_b"], ["close_all"]]
        },
        %{
          name: :close_c,
          check: [%{eval: %{type: "math/eq", a: %{pointer_get: "/open/c"}, b: true}}],
          subtasks: [["a_close_c"], ["close_all"]]
        },
        %{
          name: :close_d,
          check: [%{eval: %{type: "math/eq", a: %{pointer_get: "/open/d"}, b: true}}],
          subtasks: [["a_close_d"], ["close_all"]]
        }
      ]
    }
  }

  @todo_list [
    [:close_all]
  ]
end
