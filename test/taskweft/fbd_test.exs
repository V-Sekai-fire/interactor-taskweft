# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule Taskweft.FBDTest do
  use ExUnit.Case, async: true

  alias Taskweft.FBD

  @fixtures Path.expand("../fixtures/fbd", __DIR__)

  defp load(rel), do: @fixtures |> Path.join(rel) |> File.read!() |> Jason.decode!()

  test "lower/1 accepts the weftspun-build compact FBD and produces HTN with all seven actions" do
    g = load("weftspun-build.fbd.jsonld")
    htn = Fbd.lower(g)

    assert htn["@type"] == "domain:Definition"
    assert htn["name"] == "weftspun_hexagonal_buildout"

    assert Map.keys(htn["actions"]) |> Enum.sort() ==
             ~w(a_embedder a_ingest a_lake a_oracle a_phenotype a_render a_slat)

    # oracle joins four preds via &<
    oracle_preds =
      htn["actions"]["a_oracle"]["body"]
      |> Enum.filter(&Map.has_key?(&1, "eval"))
      |> Enum.map(fn c -> c["eval"]["a"]["pointer"] end)
      |> Enum.sort()

    assert oracle_preds == ~w(/done/embedder /done/ingest /done/phenotype /done/slat)
  end

  test "to_fbd/1 on a lowered HTN reproduces the canonical compact FBD" do
    g = load("weftspun-build.fbd.jsonld")
    back = g |> Fbd.lower() |> Fbd.to_fbd()
    assert Fbd.canon(back["S"]) == Fbd.canon(g["S"])
    assert back["V"] == g["V"]
    assert back["sfc"] == g["sfc"]
  end

  test "lower/to_fbd is idempotent on canonical FBD (round-trip identity)" do
    g = load("weftspun-build.fbd.jsonld")
    once = g |> Fbd.lower() |> Fbd.to_fbd()
    twice = once |> Fbd.lower() |> Fbd.to_fbd()
    assert Fbd.canon(once) == Fbd.canon(twice)
  end

  test "OR-divergence fixture lowers into a chooser method (RFD 2143 stage 1)" do
    g = load("blocks_get_or.fbd.jsonld")
    htn = Fbd.lower(g)

    # The chooser method replaces the individual m_pickup_from_table /
    # m_unstack skip-or-do methods; those two names should not appear.
    assert Map.has_key?(htn["methods"], "m_choose_after_find")
    refute Map.has_key?(htn["methods"], "m_pickup_from_table")
    refute Map.has_key?(htn["methods"], "m_unstack")

    alts = htn["methods"]["m_choose_after_find"]["alternatives"]
    assert length(alts) == 2
    assert Enum.map(alts, & &1["name"]) |> Enum.sort() == ["pickup_from_table", "unstack"]

    # Each alternative's check is the branch's own receptivity (X.found here),
    # producing an eq-guard on /done/found.
    for alt <- alts do
      [%{"eval" => eval} | _] = alt["check"]
      assert eval["a"]["pointer"] == "/done/found"
    end

    # The buildout sequence names the chooser exactly once, in place of
    # both branches.
    subtasks = htn["methods"]["buildout"]["alternatives"] |> hd() |> Map.get("subtasks")
    flat = Enum.map(subtasks, fn [m] -> m end)
    assert "m_choose_after_find" in flat
    assert Enum.count(flat, &(&1 == "m_choose_after_find")) == 1
  end

  test "hand-authored HTN normalises after one raise/lower pass and is then idempotent" do
    h = load("weftspun-build.domain.jsonld")
    once = h |> Fbd.to_fbd() |> Fbd.lower()
    twice = once |> Fbd.to_fbd() |> Fbd.lower()
    assert Fbd.canon(once) == Fbd.canon(twice)

    # the hand-authored form carries transitively-redundant guards on
    # a_oracle and a_phenotype; the normalised form drops them
    normalized_oracle =
      once["actions"]["a_oracle"]["body"]
      |> Enum.filter(&Map.has_key?(&1, "eval"))
      |> length()

    hand_oracle =
      h["actions"]["a_oracle"]["body"]
      |> Enum.filter(&Map.has_key?(&1, "eval"))
      |> length()

    assert hand_oracle == 4
    assert normalized_oracle == 4
  end
end
