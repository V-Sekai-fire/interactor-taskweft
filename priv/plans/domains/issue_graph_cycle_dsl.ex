# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

# issue_graph with one edge reversed, so a blocks b and b blocks a.
#
# The control for issue_graph. That domain's plan is only evidence that the
# preconditions decided the order if a graph whose preconditions cannot be
# satisfied is refused, and a tracker refuses this one too: a block cascades
# to what it blocks, so neither issue can ever close.
#
# Required to be unplannable.

defmodule IssueGraphCycle do
  use Taskweft.DSL

  @name "issue_graph_cycle"

  @variables %{
    open: %{type: :bool, init: %{a: true, b: true, c: true, d: true}}
  }

  @actions %{
    a_close_a: %{
      params: [],
      body: [
        %{eval: %{type: "math/eq", a: %{pointer_get: "/open/b"}, b: false}},
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
