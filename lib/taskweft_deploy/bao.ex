defmodule TaskweftDeploy.Bao do
  @moduledoc """
  Reads deployment secrets from OpenBao over mutual TLS.

  The listener at `weftspun-bao.internal:8200` sets
  `tls_require_and_verify_client_cert`, so a 6PN neighbour is not trusted by
  position: every read presents a certificate the Bao CA signed. `:httpc`
  rather than an HTTP client dependency, because this ships inside a single
  binary and OTP already has one.

  The SNI matters. The listener certificate names `weftspun-bao.internal`, and
  a request to the address literal returns an empty body rather than an error,
  which reads exactly like a dead server.
  """
  @default_addr "https://weftspun-bao.internal:8200"
  @timeout 10_000

  @doc "True when this deployment is configured to read from Bao at all."
  def configured?, do: tls_options() != nil

  @doc """
  Read one key out of a KV v2 secret. Returns `{:ok, value}`, or `{:error,
  reason}` — never a default, because a secret that silently falls back to a
  generated value is the failure this module exists to remove.
  """
  def read(mount, path, key) do
    with {:ok, tls} <- require_tls(),
         {:ok, token} <- require_token(),
         url <- ~c"#{addr()}/v1/#{mount}/data/#{path}",
         headers <- [{~c"x-vault-token", to_charlist(token)}],
         {:ok, body} <- request(url, headers, tls) do
      extract(body, key)
    end
  end

  defp request(url, headers, tls) do
    case :httpc.request(:get, {url, headers}, [ssl: tls, timeout: @timeout], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, status, _}, _headers, body}} -> {:error, {:http, status, body}}
      {:error, reason} -> {:error, {:transport, reason}}
    end
  end

  defp extract(body, key) do
    case :json.decode(body) do
      %{"data" => %{"data" => data}} ->
        case Map.fetch(data, key) do
          {:ok, value} -> {:ok, value}
          :error -> {:error, {:missing_key, key}}
        end

      _ ->
        {:error, :unparsable}
    end
  end

  defp require_tls do
    case tls_options() do
      nil -> {:error, :not_configured}
      tls -> {:ok, tls}
    end
  end

  defp require_token do
    case System.get_env("BAO_TOKEN") do
      token when is_binary(token) and token != "" -> {:ok, token}
      _ -> {:error, :no_token}
    end
  end

  defp tls_options do
    cert = System.get_env("BAO_CLIENT_CERT")
    key = System.get_env("BAO_CLIENT_KEY")
    ca = System.get_env("BAO_CA_CHAIN")

    if is_binary(cert) and is_binary(key) and is_binary(ca) and
         File.exists?(cert) and File.exists?(key) and File.exists?(ca) do
      [
        certfile: to_charlist(cert),
        keyfile: to_charlist(key),
        cacertfile: to_charlist(ca),
        verify: :verify_peer,
        versions: [:"tlsv1.3"],
        server_name_indication: to_charlist(sni())
      ]
    end
  end

  defp addr, do: System.get_env("BAO_ADDR") || @default_addr

  defp sni do
    addr() |> URI.parse() |> Map.get(:host) || "weftspun-bao.internal"
  end
end
