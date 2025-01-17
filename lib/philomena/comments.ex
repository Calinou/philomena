defmodule Philomena.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Notifications
  alias Philomena.Versions

  @doc """
  Gets a single comment.

  Raises `Ecto.NoResultsError` if the Comment does not exist.

  ## Examples

      iex> get_comment!(123)
      %Comment{}

      iex> get_comment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Creates a comment.

  ## Examples

      iex> create_comment(%{field: value})
      {:ok, %Comment{}}

      iex> create_comment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_comment(image, attribution, params \\ %{}) do
    comment =
      Ecto.build_assoc(image, :comments)
      |> Comment.creation_changeset(params, attribution)

    image_query =
      Image
      |> where(id: ^image.id)

    Multi.new
    |> Multi.insert(:comment, comment)
    |> Multi.update_all(:image, image_query, inc: [comments_count: 1])
    |> Multi.run(:subscribe, fn _repo, _changes ->
      Images.create_subscription(image, attribution[:user])
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  def notify_comment(comment) do
    spawn fn ->
      image =
        comment
        |> Repo.preload(:image)
        |> Map.fetch!(:image)

      subscriptions =
        image
        |> Repo.preload(:subscriptions)
        |> Map.fetch!(:subscriptions)

      Notifications.notify(
        comment,
        subscriptions,
        %{
          actor_id: image.id,
          actor_type: "Image",
          actor_child_id: comment.id,
          actor_child_type: "Comment",
          action: "commented on"
        }
      )
    end

    comment
  end

  @doc """
  Updates a comment.

  ## Examples

      iex> update_comment(comment, %{field: new_value})
      {:ok, %Comment{}}

      iex> update_comment(comment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_comment(%Comment{} = comment, editor, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    current_body = comment.body
    current_reason = comment.edit_reason

    comment_changes =
      Comment.changeset(comment, attrs, now)

    Multi.new
    |> Multi.update(:comment, comment_changes)
    |> Multi.run(:version, fn _repo, _changes ->
      Versions.create_version("Comment", comment.id, editor.id, %{
        "body" => current_body,
        "edit_reason" => current_reason
      })
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  @doc """
  Deletes a Comment.

  ## Examples

      iex> delete_comment(comment)
      {:ok, %Comment{}}

      iex> delete_comment(comment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.

  ## Examples

      iex> change_comment(comment)
      %Ecto.Changeset{source: %Comment{}}

  """
  def change_comment(%Comment{} = comment) do
    Comment.changeset(comment, %{})
  end

  def reindex_comment(%Comment{} = comment) do
    spawn fn ->
      Comment
      |> preload(^indexing_preloads())
      |> where(id: ^comment.id)
      |> Repo.one()
      |> Comment.index_document()
    end

    comment
  end

  def indexing_preloads do
    [:user, image: :tags]
  end
end
