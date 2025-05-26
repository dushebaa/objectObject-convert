defmodule ConverterElixir.Services.FileProcessor do
  use GenServer
  require Logger
  alias ConverterElixir.Constants.FileStatus
  alias ConverterElixirWeb.Files

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state_with_rabbitmq} = setup_rabbitmq()
    {:ok, state_with_rabbitmq}
  end

  defp setup_rabbitmq do
    {:ok, connection} = AMQP.Connection.open(Application.get_env(:converter_elixir, :amqp)[:url])
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, "file_tasks")
    # Set up queue consumer
    {:ok, _consumer_tag} = AMQP.Basic.consume(channel, "file_tasks", nil, no_ack: false)
    Logger.info("RabbitMQ consumer started")
    {:ok, %{channel: channel, connection: connection}}
  end

  # Handle the basic_consume_ok message
  def handle_info({:basic_consume_ok, meta}, state) do
    Logger.info("Consumer registered: #{inspect(meta)}")
    {:noreply, state}
  end

  # Handle actual message delivery
  def handle_info({:basic_deliver, payload, meta}, state = %{channel: channel}) do
    Logger.info("Received message: #{payload}")

    case Jason.decode(payload) do
      {:ok, %{"file_id" => file_id, "file_path" => file_path, "output_format" => output_format}} ->
        # Process in the same process for simplicity
        process_file(file_id, file_path, output_format)
        AMQP.Basic.ack(channel, meta.delivery_tag)

      error ->
        Logger.error("Failed to decode message: #{inspect(error)}")
        AMQP.Basic.reject(channel, meta.delivery_tag, requeue: false)
    end

    {:noreply, state}
  end

  defp process_file(file_id, file_path, output_format) do
    Logger.info("Starting conversion of file #{file_id}")

    # Update status to processing
    case Files.update_file_status(file_id, FileStatus.processing()) do
      {:ok, _} ->
        Logger.info("Updated status to processing")
        output_dir = Path.join([System.tmp_dir!(), "converted"])
        File.mkdir_p!(output_dir)
        output_path = Path.join(output_dir, "#{file_id}.#{output_format}")

        Logger.info("Converting file from #{file_path} to #{output_path}")

        case System.cmd("ffmpeg", ["-i", file_path, output_path], stderr_to_stdout: true) do
          {_output, 0} ->
            Logger.info("Conversion successful")
            Files.update_file_status(file_id, FileStatus.finished())

          {error, code} ->
            Logger.error("Conversion failed with code #{code}: #{inspect(error)}")
            Files.update_file_status(file_id, FileStatus.error())
        end

      error ->
        Logger.error("Failed to update status: #{inspect(error)}")
    end
  end

  # Handle other RabbitMQ messages
  def handle_info({:basic_cancel, _}, state), do: {:noreply, state}
  def handle_info({:basic_cancel_ok, _}, state), do: {:noreply, state}
  def handle_info({:basic_return, _}, state), do: {:noreply, state}
end
