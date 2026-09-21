# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule Mix.Tasks.Taskweft.FBD.Lower do
  @moduledoc """
  Lower a directory of compact IEC 60848 FBD JSON-LD files
  (aligned with Project-AGRAFE) into taskweft HTN JSON.

      mix taskweft.fbd.lower --in <dir> --out <dir>

  Reads every `*.fbd.jsonld` under `--in`, lowers each via
  `Taskweft.FBD.lower/1`, writes to `--out/<stem>.htn.jsonld`.
  """
  use Mix.Task

  alias Taskweft.FBD

  @shortdoc "Lower compact FBD personas to HTN JSON"

  @impl true
  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: [in: :string, out: :string])
    in_dir = Keyword.fetch!(opts, :in)
    out_dir = Keyword.fetch!(opts, :out)
    File.mkdir_p!(out_dir)

    files = Path.wildcard(Path.join(in_dir, "*.fbd.jsonld"))

    if files == [] do
      Mix.raise("no *.fbd.jsonld files under #{in_dir}")
    end

    for f <- files do
      stem = Path.basename(f, ".fbd.jsonld")
      htn = f |> File.read!() |> Jason.decode!() |> Fbd.lower()
      out = Path.join(out_dir, "#{stem}.htn.jsonld")
      File.write!(out, Jason.encode_to_iodata!(htn, pretty: true))
      Mix.shell().info("#{stem}: #{length(Map.keys(htn["actions"]))} actions -> #{out}")
    end
  end
end
