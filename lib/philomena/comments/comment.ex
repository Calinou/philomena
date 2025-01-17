defmodule Philomena.Comments.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  use Philomena.Elasticsearch,
    definition: Philomena.Comments.Elasticsearch,
    index_name: "comments",
    doc_type: "comment"

  alias Philomena.Images.Image
  alias Philomena.Users.User

  schema "comments" do
    belongs_to :user, User
    belongs_to :image, Image
    belongs_to :deleted_by, User

    field :body, :string
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :referrer, :string, default: ""
    field :anonymous, :boolean, default: false
    field :hidden_from_users, :boolean, default: false
    field :edit_reason, :string
    field :edited_at, :utc_datetime
    field :deletion_reason, :string, default: ""
    field :destroyed_content, :boolean, default: false
    field :name_at_post_time, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def creation_changeset(comment, attrs, attribution) do
    comment
    |> cast(attrs, [:body, :anonymous])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(attribution)
    |> put_name_at_post_time(attribution[:user])
  end

  def changeset(comment, attrs, edited_at \\ nil) do
    comment
    |> cast(attrs, [:body, :edit_reason])
    |> put_change(:edited_at, edited_at)
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> validate_length(:edit_reason, max: 70, count: :bytes)
  end

  defp put_name_at_post_time(changeset, nil), do: changeset
  defp put_name_at_post_time(changeset, user), do: change(changeset, name_at_post_time: user.name)
end
