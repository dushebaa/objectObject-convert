defmodule ConverterElixirWeb.FileController do
  use ConverterElixirWeb, :controller

  require Logger
  alias ConverterElixirWeb.Files
  alias ConverterElixirWeb.Files.File, as: FileSchema  # Rename to avoid confusion
  alias :file, as: FileSystem  # Use Erlang's file module explicitly

  def process(conn, %{"file" => file_upload, "output_format" => output_format}) do
    user = conn.assigns.current_user
    Logger.info("Processing request for user #{user.id}")

    file_id = Ecto.UUID.generate()
    file_path = Path.join(System.tmp_dir!(), file_id)
    Logger.info("Saving file to #{file_path}")

    # Copy uploaded file to temporary location
    File.copy(file_upload.path, file_path)

    {:ok, file} = Files.create_file(%{filename: file_upload.filename, user_id: user.id, output_format: output_format})
    Logger.info("Created file record with id #{file.id}")

    message = Jason.encode!(%{
      "file_id" => file.id,
      "file_path" => file_path,
      "output_format" => output_format
    })
    Logger.info("Publishing message to RabbitMQ: #{message}")

    {:ok, connection} = AMQP.Connection.open(Application.get_env(:converter_elixir, :amqp)[:url])
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, "file_tasks")
    AMQP.Basic.publish(channel, "", "file_tasks", message)
    AMQP.Connection.close(connection)

    conn
    |> put_status(:created)
    |> json(%{file_id: file.id, file_name: file.filename})
  end

  def status(conn, %{"file_id" => file_id}) do
    user = conn.assigns.current_user

    case Files.get_file(file_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "File not found"})

      file ->
        if file.user_id == user.id do
          response = %{
            status: file.status,
            filename: file.filename,
            file_id: file.id
          }

          response = if file.status == "finished" do
            Map.put(response, :download_url, "/files/#{file.id}/download")
          else
            response
          end

          conn
          |> put_status(:ok)
          |> json(response)
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Access denied"})
        end
    end
  end

  def download(conn, %{"file_id" => file_id}) do
    user = conn.assigns.current_user

    case Files.get_file(file_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "File not found"})

      file ->
        if file.user_id == user.id do
          if file.status == "finished" do
            output_path = Path.join([System.tmp_dir!(), "converted", "#{file_id}.#{file.output_format}"])

            if File.exists?(output_path) do
              conn
              |> put_resp_content_type(MIME.type(file.output_format))
              |> put_resp_header("content-disposition", ~s(attachment; filename="#{file.filename}.#{file.output_format}"))
              |> send_file(200, output_path)
            else
              conn
              |> put_status(:not_found)
              |> json(%{error: "File not found on disk"})
            end
          else
            conn
            |> put_status(:bad_request)
            |> json(%{error: "File is not ready for download"})
          end
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Access denied"})
        end
    end
  end

  def options(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{})
  end
end
