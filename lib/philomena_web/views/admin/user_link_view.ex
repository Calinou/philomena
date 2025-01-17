defmodule PhilomenaWeb.Admin.UserLinkView do
  use PhilomenaWeb, :view

  import Philomena.Tags.Tag, only: [display_order: 1]

  def link_state_class(%{aasm_state: state}) when state in ["verified", "link_verified"], do: "success"
  def link_state_class(%{aasm_state: state}) when state in ["unverified", "rejected"], do: "danger"
  def link_state_class(%{aasm_state: "contacted"}), do: "warning"
  def link_state_class(_link), do: nil

  def link_state_name(%{aasm_state: state}) do
    state
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def link_scope(conn) do
    case conn.params["all"] do
      nil  -> []
      _val -> [all: true]
    end
  end

  def contacted?(%{aasm_state: state}), do: state == "contacted"
  def verified?(%{aasm_state: state}), do: state == "verified"
  def link_verified?(%{aasm_state: state}), do: state == "link_verified"
  def unverified?(%{aasm_state: state}), do: state == "unverified"
  def rejected?(%{aasm_state: state}), do: state == "rejected"

  def public_text(%{public: true}), do: "Yes"
  def public_text(_user_link), do: "No"

  def public?(%{public: public}), do: !!public
end
