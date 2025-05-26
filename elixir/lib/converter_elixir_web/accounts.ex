defmodule ConverterElixirWeb.Accounts do
  alias ConverterElixir.Repo
  alias ConverterElixir.Accounts.User
  require Logger


  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(username, password) do
    Logger.info("Attempting to authenticate user: #{username}")

    user = Repo.get_by(User, username: username)
    case user do
      nil ->
        Logger.warning("Authentication failed: user not found - #{username}")
        {:error, :not_found}
      user ->
        if password == user.password do
          Logger.info("User password is: #{password} and received password is: #{user.password}")
          Logger.info("User authenticated successfully: #{username}")
          {:ok, user}
        else
          Logger.warning("Authentication failed: invalid password for user - #{username}")
          {:error, :invalid_password}  # Changed from :not_found to :invalid_password
        end
    end
  end

  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by_username(username), do: Repo.get_by(User, username: username)
  def get_user(id) do
    Repo.get(User, id)
  end
end
