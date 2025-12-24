defmodule CAStore do
  @moduledoc """
  Minimal CAStore-compatible stub that delegates to the system certificate bundle.
  """

  @doc """
  Returns path to a PEM-encoded CA certificate bundle. Defaults to the system
  certificate file unless overridden via the `CASTORE_CERTFILE` environment
  variable.
  """
  @spec file_path() :: String.t()
  def file_path do
    System.get_env("CASTORE_CERTFILE", "/etc/ssl/certs/ca-certificates.crt")
  end

  @doc """
  Returns the in-memory CA certificates if available from the OTP distribution.
  """
  @spec default_ca_certs() :: [term()] | :undefined
  def default_ca_certs do
    case :public_key.cacerts_get() do
      {:ok, certs} -> certs
      {:error, _} -> :undefined
    end
  end
end
