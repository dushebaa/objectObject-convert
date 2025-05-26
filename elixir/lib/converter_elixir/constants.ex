defmodule ConverterElixir.Constants do
  defmodule FileStatus do
    def pending, do: "pending"
    def processing, do: "processing"
    def finished, do: "finished"
    def error, do: "error"
  end
end
