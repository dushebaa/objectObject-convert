defmodule ConverterElixirWeb.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
  end

  pipeline :auth do
    plug ConverterElixirWeb.Auth.Pipeline
  end

  scope "/auth", ConverterElixirWeb do
    pipe_through :api
    options "/login", AuthController, :options
    options "/signup", AuthController, :options
    post "/signup", AuthController, :signup
    post "/login", AuthController, :login
  end

  scope "/files", ConverterElixirWeb do
    pipe_through [:api, :auth]
    options "/process", FileController, :options
    options "/:file_id/status", FileController, :options
    options "/:file_id/download", FileController, :options
    post "/process", FileController, :process
    get "/:file_id/status", FileController, :status
    get "/:file_id/download", FileController, :download
  end
end
