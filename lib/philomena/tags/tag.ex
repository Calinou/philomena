defmodule Philomena.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  use Philomena.Elasticsearch,
    definition: Philomena.Tags.Elasticsearch,
    index_name: "tags",
    doc_type: "tag"

  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.UserLinks.UserLink
  alias Philomena.Tags.Tag
  alias Philomena.Slug

  @namespaces [
    "artist",
    "art pack",
    "ask",
    "blog",
    "colorist",
    "comic",
    "editor",
    "fanfic",
    "oc",
    "parent",
    "parents",
    "photographer",
    "series",
    "species",
    "spoiler",
    "video"
  ]

  @namespace_categories %{
    "artist" => "origin",
    "art pack" => "content-fanmade",
    "colorist" => "origin",
    "comic" => "content-fanmade",
    "editor" => "origin",
    "fanfic" => "content-fanmade",
    "oc" => "oc",
    "photographer" => "origin",
    "series" => "content-fanmade",
    "spoiler" => "spoiler",
    "video" => "content-fanmade"
  }

  @derive {Phoenix.Param, key: :slug}

  schema "tags" do
    belongs_to :aliased_tag, Tag, source: :aliased_tag_id
    has_many :aliases, Tag, foreign_key: :aliased_tag_id
    many_to_many :implied_tags, Tag, join_through: "tags_implied_tags", join_keys: [tag_id: :id, implied_tag_id: :id]
    many_to_many :implied_by_tags, Tag, join_through: "tags_implied_tags", join_keys: [implied_tag_id: :id, tag_id: :id]
    has_many :public_links, UserLink, where: [public: true, aasm_state: "verified"]
    has_many :dnp_entries, DnpEntry, where: [aasm_state: "listed"]

    field :slug, :string
    field :name, :string
    field :category, :string
    field :images_count, :integer, default: 0
    field :description, :string
    field :short_description, :string
    field :namespace, :string
    field :name_in_namespace, :string
    field :image, :string
    field :image_format, :string
    field :image_mime_type, :string
    field :mod_notes, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def creation_changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> put_slug()
    |> put_name_and_namespace()
    |> put_namespace_category()
  end

  def parse_tag_list(list) do
    list
    |> to_string()
    |> String.split(",")
    |> Enum.map(&clean_tag_name/1)
    |> Enum.reject(&"" == &1)
  end

  def display_order(tags) do
    tags
    |> Enum.sort_by(&{
      &1.category != "rating",
      &1.category != "origin",
      &1.category != "character",
      &1.category != "oc",
      &1.category != "species",
      &1.category != "content-fanmade",
      &1.category != "content-official",
      &1.category != "spoiler",
      &1.name
    })
  end

  def clean_tag_name(name) do
    # Downcase, replace extra runs of spaces, replace unicode quotes
    # with ascii quotes, trim space from end
    name
    |> String.downcase()
    |> String.replace(~r/[[:space:]]+/, " ")
    |> String.replace(~r/[\x{00b4}\x{2018}\x{2019}\x{201a}\x{201b}\x{2032}]/u, "'")
    |> String.replace(~r/[\x{201c}\x{201d}\x{201e}\x{201f}\x{2033}]/u, "\"")
    |> String.trim()
    |> clean_tag_namespace()
    |> ununderscore()
  end

  defp clean_tag_namespace(name) do
    # Remove extra spaces after the colon in a namespace
    # (artist:, oc:, etc.)
    name
    |> String.split(":", parts: 2)
    |> Enum.map(&String.trim/1)
    |> join_namespace_parts(name)
  end

  defp join_namespace_parts([_name], original_name),
    do: original_name
  defp join_namespace_parts([namespace, name], _original_name) when namespace in @namespaces,
    do: namespace <> ":" <> name
  defp join_namespace_parts([_namespace, _name], original_name),
    do: original_name

  defp ununderscore(<<"artist:", _rest::binary>> = name),
    do: name
  defp ununderscore(name),
    do: String.replace(name, "_", " ")

  defp put_slug(changeset) do
    slug =
      changeset
      |> get_field(:name)
      |> to_string()
      |> Slug.slug()

    changeset
    |> change(slug: slug)
  end

  defp put_name_and_namespace(changeset) do
    {namespace, name_in_namespace} =
      changeset
      |> get_field(:name)
      |> to_string()
      |> extract_name_and_namespace()

    changeset
    |> change(namespace: namespace)
    |> change(name_in_namespace: name_in_namespace)
  end

  defp extract_name_and_namespace(name) do
    case String.split(name, ":", parts: 2) do
      [namespace, name_in_namespace] when namespace in @namespaces ->
        {namespace, name_in_namespace}

      _value ->
        {nil, name}
    end
  end

  defp put_namespace_category(changeset) do
    namespace = changeset |> get_field(:namespace)

    case @namespace_categories[namespace] do
      nil      -> changeset
      category -> change(changeset, category: category)
    end
  end
end
