# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule Taskweft.FBD.Static do
  @moduledoc """
  Static analyser for compact FBD documents. Wraps
  `libfbd_static` from `thirdparty/taskweft-fbd-static` via
  the NIF at `priv/fbd_static_nif.so`.

  Two structural analyses per RFD 2144:

    * `reachable` — step ids reachable from the initial marking
    * `concurrent_pairs` — ordered `[a, b]` pairs that co-occur in
      some reachable marking

  Abstract interpretation is staged (see RFD 2144's staging table).

  ## Example

      iex> {:ok, json} = Taskweft.FBD.Static.analyse(File.read!("chart.fbd.jsonld"))
      iex> Jason.decode!(json)
      %{"reachable" => ["init", "find", ...], "concurrent_pairs" => [["a", "b"]]}
  """

  alias Taskweft.FBD.Static.Nif

  @doc "Analyse a compact FBD JSON document. Returns `{:ok, json_reply}`."
  @spec analyse(iodata()) :: {:ok, binary()}
  def analyse(sfc_json), do: Nif.analyse(sfc_json)
end

defmodule Taskweft.FBD.Static.Nif do
  @moduledoc false
  @on_load :load

  def load do
    path = :filename.join(:code.priv_dir(:taskweft), ~c"fbd_static_nif")

    case :erlang.load_nif(path, 0) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("failed to load fbd_static_nif: #{inspect(reason)}")
        :ok
    end
  end

  def analyse(_sfc_json), do: :erlang.nif_error(:not_loaded)
end
