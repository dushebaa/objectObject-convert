defmodule ConverterElixirWeb.AuthController do
  use ConverterElixirWeb, :controller
  require Logger
  alias ConverterElixirWeb.Accounts
  alias ConverterElixirWeb.Auth.Guardian

  def signup(conn, %{"username" => username, "password" => password}) do
    with {:ok, user} <- Accounts.create_user(%{username: username, password: password}),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      Redix.command(:redix, ["SETEX", "session:#{username}", "3600", token])
      conn
      |> put_status(:created)
      |> json(%{token: token})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create user"})
    end
  end

  def login(conn, %{"username" => username, "password" => password} = params) do
    Logger.debug("Request params: #{inspect(params)}")

    with {:ok, user} <- Accounts.authenticate_user(username, password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      Redix.command(:redix, ["SETEX", "session:#{username}", "3600", token])
      conn
      |> json(%{token: token})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not found"})

      {:error, :invalid_password} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid password"})

      {:error, :secret_not_found} ->
        Logger.error("Guardian secret not configured")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Authentication service configuration error"})

      error ->
        Logger.error("Unexpected error during login: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Authentication failed"})
    end
  end

  def options(conn, _params) do
    conn
    |> put_status(200)
    |> text("")
  end
end
