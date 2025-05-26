defmodule ConverterElixirWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :converter_elixir,
    module: ConverterElixirWeb.Auth.Guardian,
    error_handler: ConverterElixirWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifyHeader,
    scheme: :none

  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug :set_current_user

  def set_current_user(conn, _) do
    current_user = Guardian.Plug.current_resource(conn)
    Plug.Conn.assign(conn, :current_user, current_user)
  end
end
