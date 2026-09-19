# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule TaskweftDeploy.Application do
  @moduledoc """
  Supervisor children for the hosted Taskweft MCP server: a Cowboy endpoint
  running `TaskweftDeploy.Router`, which bridges MCP-client OAuth to GitHub
  login (via `oauth_mcp_bridge`) and gates MCP requests behind a macaroon
  access token. No database, no volume — all OAuth state is a stateless
  macaroon, so scale-to-zero restarts lose nothing.

  Not its own OTP application anymore — folded in from the formerly-separate
  `deploy/` Mix project (one Mix project, one mix.lock, no synced-across-
  two-lockfiles class of bug). `Taskweft.Application` calls `children/0` and
  starts the result under its own supervisor when running as the
  `taskweft_deploy` release.

  Runtime env:

    * `PORT` — listen port (default 8080; Fly maps 443/TLS → this).
    * `TASKWEFT_TOKEN_SECRET` — macaroon root key (**required in prod**; a stable
      value so tokens survive restarts). A random key is used if unset (dev only).
    * `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` — the GitHub OAuth app.
    * `TASKWEFT_MCP_GH_ALLOW` — whitelist (comma list; bare = login, `@name`/`org:name` = org). Default `fire`.
    * `PUBLIC_BASE_URL` — external URL (issuer); derived from Fly's forwarded headers if unset.
  """

  require Logger

  alias OAuthMCPBridge.Whitelist

  @doc """
  Supervisor children for the hosted MCP web server, or `{:error, reason}` when
  a required secret is unavailable.
  """
  def children do
    case fetch_token_secret() do
      {:ok, secret} -> children(secret)
      {:error, reason} -> {:error, reason}
    end
  end

  defp children(token_secret) do
    :persistent_term.put({:oauth_mcp_bridge, :token_secret}, token_secret)

    :persistent_term.put(
      {:oauth_mcp_bridge, :auth},
      Whitelist.parse(env("TASKWEFT_MCP_GH_ALLOW", "fire"))
    )

    :persistent_term.put(
      {:oauth_mcp_bridge, :github},
      %{client_id: env("GITHUB_CLIENT_ID", ""), client_secret: env("GITHUB_CLIENT_SECRET", "")}
    )

    :persistent_term.put({:oauth_mcp_bridge, :service}, %{
      name: "Taskweft MCP",
      documentation_url: "https://github.com/V-Sekai-fire/interactor-taskweft"
    })

    :persistent_term.put({:oauth_mcp_bridge, :page}, %{
      title: "taskweft",
      tagline:
        "Hosted HTN planner MCP server — plan / replan over JSON-LD domains, gated by GitHub sign-in (OAuth 2.1).",
      server_name: "taskweft",
      links: [
        {"taskweft/taskweft", "https://github.com/V-Sekai-fire/interactor-taskweft"}
      ]
    })

    case env("PUBLIC_BASE_URL", nil) do
      url when is_binary(url) and url != "" ->
        :persistent_term.put({:oauth_mcp_bridge, :base_url}, url)

      _ ->
        :ok
    end

    port = String.to_integer(env("PORT", "8080"))
    Logger.info("taskweft MCP (OAuth/GitHub) listening on 0.0.0.0:#{port}")

    [
      {Plug.Cowboy,
       scheme: :http, plug: TaskweftDeploy.Router, options: [port: port, ip: {0, 0, 0, 0}]}
    ]
  end

  # An ephemeral key invalidates every issued token on restart, so where Bao is
  # configured a failed read is an error the caller reports rather than a
  # fallback to a generated one.
  defp fetch_token_secret do
    case bao_token_secret() do
      {:ok, secret} -> validate_secret(secret)
      {:error, reason} -> {:error, {:bao_read_failed, reason}}
      :not_configured -> env_token_secret()
    end
  end

  defp bao_token_secret do
    if TaskweftDeploy.Bao.configured?() do
      TaskweftDeploy.Bao.read("secret", "taskweft", "token_secret")
    else
      :not_configured
    end
  end

  defp env_token_secret do
    case env("TASKWEFT_TOKEN_SECRET", nil) do
      secret when is_binary(secret) ->
        validate_secret(secret)

      _ ->
        Logger.warning(
          "TASKWEFT_TOKEN_SECRET unset — using an ephemeral dev key (tokens won't survive restart)"
        )

        {:ok, :crypto.strong_rand_bytes(32)}
    end
  end

  defp validate_secret(secret) when is_binary(secret) and byte_size(secret) >= 16,
    do: {:ok, secret}

  defp validate_secret(_secret), do: {:error, :token_secret_too_short}

  defp env(name, default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      v -> v
    end
  end
end
