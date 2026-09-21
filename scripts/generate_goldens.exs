# Run: elixir -S mix run scripts/generate_goldens.exs
# Generates _expected.json golden files for every domain+problem pair.

domains_dir = "priv/plans/domains"
problems_dir = "priv/plans/problems"
expected_dir = "priv/plans/expected"
File.mkdir_p!(expected_dir)

# The pairs and the standalone list are read off the filesystem rather than
# written here. Restating them let nine domains be deleted while this script
# still named them, so it died on the first one instead of reporting the drift:
# eleven were named and two existed.
#
# A problem belongs to the domain whose name prefixes it. A problem that
# matches none is an orphan, and is counted and named rather than skipped
# silently -- the deleted domains left theirs behind.

domains =
  Path.wildcard(Path.join(domains_dir, "*_dsl.ex"))
  |> Enum.map(&(Path.basename(&1) |> String.replace_suffix("_dsl.ex", "")))
  |> Enum.concat(
    Path.wildcard(Path.join(domains_dir, "*.jsonld"))
    |> Enum.map(&(Path.basename(&1) |> String.replace_suffix(".jsonld", "")))
  )
  |> Enum.uniq()
  |> Enum.sort()

problems =
  Path.wildcard(Path.join(problems_dir, "*.jsonld"))
  |> Enum.map(&(Path.basename(&1) |> String.replace_suffix(".jsonld", "")))
  |> Enum.sort()

# Longest prefix wins, so issue_graph_cycle takes its own problems rather than
# issue_graph taking them.
owner = fn problem ->
  domains
  |> Enum.filter(&String.starts_with?(problem, &1 <> "_"))
  |> Enum.max_by(&String.length/1, fn -> nil end)
end

pairs = for p <- problems, d = owner.(p), do: {d, p}
orphans = for p <- problems, is_nil(owner.(p)), do: p
standalone = domains -- Enum.map(pairs, fn {d, _} -> d end)

IO.puts("#{length(domains)} domain(s), #{length(pairs)} pair(s), " <>
        "#{length(standalone)} standalone, #{length(orphans)} orphan problem(s)")

if orphans != [] do
  IO.puts("orphan problems, named because a silent skip reads as a pass:")
  for o <- orphans, do: IO.puts("  #{o}")
end

# Skill allocation times out — skip for now (noted in test)
# {"skill_allocation", "skill_allocation_mzn_1m_2"}, etc.

# ── generate ──

# Domains are _dsl.ex and are compiled; the .jsonld form is what a few of them
# still ship instead. The tests read them this way, and this script read only
# the .jsonld form, so it died on the first domain that had none.
domain_json = fn name ->
  dsl = Path.join(domains_dir, "#{name}_dsl.ex")
  jsonld = Path.join(domains_dir, "#{name}.jsonld")

  cond do
    File.exists?(dsl) ->
      case File.read!(dsl) |> Taskweft.DSL.compile() do
        {:ok, json} -> json
        {:error, _} -> File.read!(jsonld)
      end

    File.exists?(jsonld) ->
      File.read!(jsonld)

    true ->
      raise "no domain for #{name}: neither #{dsl} nor #{jsonld}"
  end
end


for {domain_name, problem_name} <- pairs do
  problem_path = Path.join(problems_dir, "#{problem_name}.jsonld")
  golden_path = Path.join(expected_dir, "#{domain_name}__#{problem_name}_expected.json")

  problem_json = File.read!(problem_path)

  merged =
    Jason.decode!(domain_json.(domain_name))
    |> Map.merge(Jason.decode!(problem_json))
    |> Jason.encode!()

  case Taskweft.plan_explain(merged) do
    {:ok, result_json} ->
      result = Jason.decode!(result_json)
      plan = result["plan"] || []
      explain = result["explain"] || %{}
      tree = get_in(explain, ["solution_tree"]) || []

      golden = %{
        "plan" => plan,
        "steps" => length(plan),
        "tree" => tree,
        "tree_nodes" => length(tree)
      }

      File.write!(golden_path, Jason.encode!(golden, pretty: true))
      IO.puts("  #{domain_name} + #{problem_name} → #{length(plan)} steps, #{length(tree)} tree nodes")
      :ok

    {:error, reason} ->
      IO.puts("  SKIP #{domain_name} + #{problem_name}: #{inspect(reason)}")
      :skip
  end
end

# ── standalone ──
for domain_name <- standalone do
  golden_path = Path.join(expected_dir, "#{domain_name}_expected.json")

  {:ok, result_json} = Taskweft.plan_explain(domain_json.(domain_name))
  result = Jason.decode!(result_json)
  plan = result["plan"] || []
  explain = result["explain"] || %{}
  tree = get_in(explain, ["solution_tree"]) || []

  golden = %{
    "plan" => plan,
    "steps" => length(plan),
    "tree" => tree,
    "tree_nodes" => length(tree)
  }

  File.write!(golden_path, Jason.encode!(golden, pretty: true))
  IO.puts("  #{domain_name} (standalone) → #{length(plan)} steps, #{length(tree)} tree nodes")
  :ok
end

written = Path.wildcard(Path.join(expected_dir, "*_expected.json")) |> length()
IO.puts("Done. #{written} golden file(s) in #{expected_dir}")
