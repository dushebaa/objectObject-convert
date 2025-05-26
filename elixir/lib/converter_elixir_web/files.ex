defmodule ConverterElixirWeb.Files do
  alias ConverterElixir.Repo
  alias ConverterElixirWeb.Files.File

  def create_file(attrs \\ %{}) do
    %File{}
    |> File.changeset(attrs)
    |> Repo.insert()
  end

  def get_file(id) do
    Repo.get(File, id)
  end

  def update_file_status(file_id, status) do
    case get_file(file_id) do
      nil -> {:error, :not_found}
      file ->
        file
        |> File.changeset(%{status: status})
        |> Repo.update()
    end
  end
end
