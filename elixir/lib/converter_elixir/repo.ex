defmodule ConverterElixir.Repo do
  use Ecto.Repo,
    otp_app: :converter_elixir,
    adapter: Ecto.Adapters.Postgres
end
