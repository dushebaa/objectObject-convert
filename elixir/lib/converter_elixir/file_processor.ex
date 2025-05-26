defmodule ConverterElixir.FileProcessor do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, connection} = AMQP.Connection.open(Application.get_env(:converter_elixir, :amqp)[:url])
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, "file_tasks")
    AMQP.Basic.consume(channel, "file_tasks", nil, no_ack: true)
    {:ok, channel}
  end

  # Подтверждение подписки
  def handle_info({:basic_consume_ok, _meta}, channel) do
    IO.puts("Successfully subscribed to queue")
    {:noreply, channel}
  end

  # Обработка сообщений из очереди
  def handle_info({:basic_deliver, payload, _meta}, channel) do
    task = Jason.decode!(payload)
    IO.inspect(task, label: "Processing task")
    # Здесь добавь свою логику обработки задачи
    {:noreply, channel}
  end

  # Отмена подписки
  def handle_info({:basic_cancel, _meta}, channel) do
    IO.puts("Subscription cancelled by server")
    {:noreply, channel}
  end

  # Подтверждение отмены подписки
  def handle_info({:basic_cancel_ok, _meta}, channel) do
    IO.puts("Subscription cancellation confirmed")
    {:noreply, channel}
  end

  # Обработка всех остальных сообщений
  def handle_info(msg, channel) do
    IO.inspect(msg, label: "Unhandled message")
    {:noreply, channel}
  end
end
