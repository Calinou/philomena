defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.ImageSorter
  alias Philomena.Interactions

  def index(conn, params) do
    user = conn.assigns.current_user
    sort = ImageSorter.parse_sort(params)

    case ImageLoader.search_string(conn, params["q"], sorts: sort.sorts, queries: sort.queries) do
      {:ok, {images, tags}} ->
        interactions =
          Interactions.user_interactions(images, user)

        conn
        |> render("index.html", images: images, tags: tags, search_query: params["q"], interactions: interactions, layout_class: "layout--wide")

      {:error, msg} ->
        render(conn, "index.html", images: [], error: msg, search_query: params["q"])
    end
  end
end
