defmodule ExampleWeb.FlowForms.FormNode do
  @moduledoc """
  Custom node component that renders a form with fields.
  """

  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    title = Map.get(assigns.node.data, :title, "Form")
    fields = Map.get(assigns.node.data, :fields, [])
    color = Map.get(assigns.node.data, :color, "#3b82f6")

    assigns =
      assigns
      |> assign(:title, title)
      |> assign(:fields, fields)
      |> assign(:color, color)

    ~H"""
    <div class="lf-form-node">
      <div class="lf-form-node-header" style={"background: #{@color}"}>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <polyline points="14 2 14 8 20 8" />
          <line x1="16" y1="13" x2="8" y2="13" />
          <line x1="16" y1="17" x2="8" y2="17" />
        </svg>
        <span>{@title}</span>
      </div>
      <div class="lf-form-node-fields">
        <div :for={field <- @fields} class="lf-form-field">
          <label class="lf-form-field-label">{field.label}</label>
          <%= case field.type do %>
            <% "select" -> %>
              <select class="nodrag">
                <option :for={opt <- Map.get(field, :options, [])} value={opt}>{opt}</option>
              </select>
            <% "textarea" -> %>
              <textarea
                class="nodrag"
                rows="2"
                placeholder={Map.get(field, :placeholder, "")}
              >{Map.get(field, :value, "")}</textarea>
            <% _ -> %>
              <input
                type={field.type}
                class="nodrag"
                placeholder={Map.get(field, :placeholder, "")}
                value={Map.get(field, :value, "")}
              />
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
