defmodule ConverterElixirWeb.Files.File do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "files" do
    field :filename, :string
    field :status, :string, default: "pending"
    field :output_format, :string
    belongs_to :user, ConverterElixir.Accounts.User, type: :integer
  end

  def changeset(file, attrs) do
    file
    |> cast(attrs, [:filename, :status, :output_format, :user_id])
    |> validate_required([:filename, :user_id, :output_format])
    |> validate_inclusion(:status, ["pending", "processing", "finished", "error"])
  end
end
