defmodule ConverterElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ConverterElixirWeb.Telemetry,
      ConverterElixir.Repo,
      {DNSCluster, query: Application.get_env(:converter_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ConverterElixir.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ConverterElixir.Finch},
      # Start a worker by calling: ConverterElixir.Worker.start_link(arg)
      # {ConverterElixir.Worker, arg},
      # Start to serve requests, typically the last entry
      ConverterElixirWeb.Endpoint,
      {Redix, name: :redix, host: Application.get_env(:converter_elixir, :redix)[:host], port: Application.get_env(:converter_elixir, :redix)[:port]},
      ConverterElixir.Services.FileProcessor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ConverterElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ConverterElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
