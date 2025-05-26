# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :converter_elixir,
  ecto_repos: [ConverterElixir.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :converter_elixir, ConverterElixirWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ConverterElixirWeb.ErrorHTML, json: ConverterElixirWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ConverterElixir.PubSub,
  live_view: [signing_salt: "DX4kwHsU"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :converter_elixir, ConverterElixir.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  converter_elixir: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  converter_elixir: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"


config :converter_elixir, ConverterElixirWeb.Auth.Guardian,
  issuer: "converter_elixir",
  secret_key: "XTouSFn3eUGfbcGmpkAj3TvLEd3S4iJr0bfEu1R8gi0uIqu4DcyphTULgWgbVraS"

config :converter_elixir, :redix, host: "localhost", port: 6379
config :converter_elixir, :amqp, url: "amqp://guest:guest@localhost"

config :cors_plug,
  origin: ["*"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent"],
  expose: ["Authorization"]
