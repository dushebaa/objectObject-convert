defmodule ConverterElixirWeb.Auth.Guardian do
  use Guardian, otp_app: :converter_elixir

  alias ConverterElixirWeb.Accounts

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
end
