defmodule Philomena.StaticPages.StaticPage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "static_pages" do
    field :title, :string
    field :slug, :string
    field :body, :string
    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(static_page, attrs) do
    static_page
    |> cast(attrs, [])
    |> validate_required([])
  end
end
