defmodule FlowExample.Samples do
  @moduledoc """
  Sample flows used across the showcase.
  """

  alias LiveFlow.{Edge, Handle, Node, State}

  @doc """
  A small order-processing workflow laid out left to right.
  """
  def pipeline(opts \\ []) do
    edge_type = Keyword.get(opts, :edge_type, :smoothstep)

    nodes = [
      card("trigger", 0, 120, "Webhook", "POST /orders", "hero-bolt", :amber, inputs: false),
      card("validate", 300, 40, "Validate", "Schema + fraud check", "hero-shield-check", :sky),
      card("enrich", 300, 220, "Enrich", "Customer & stock data", "hero-circle-stack", :violet),
      card("route", 600, 120, "Route", "Split by region", "hero-arrows-pointing-out", :sky),
      card("notify", 900, 40, "Notify", "Email + Slack", "hero-bell-alert", :emerald),
      card("archive", 900, 220, "Archive", "S3 cold storage", "hero-archive-box", :slate,
        outputs: false
      )
    ]

    edges = [
      Edge.new("e-trigger-validate", "trigger", "validate", type: edge_type, animated: true),
      Edge.new("e-trigger-enrich", "trigger", "enrich", type: edge_type, animated: true),
      Edge.new("e-validate-route", "validate", "route", type: edge_type),
      Edge.new("e-enrich-route", "enrich", "route", type: edge_type),
      Edge.new("e-route-notify", "route", "notify",
        type: edge_type,
        label: "EU",
        marker_end: %{type: :arrow_closed}
      ),
      Edge.new("e-route-archive", "route", "archive",
        type: edge_type,
        label: "US",
        marker_end: %{type: :arrow_closed}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end

  @doc """
  A card node rendered by `FlowExampleWeb.FlowNodes.card/1`.
  """
  def card(id, x, y, title, subtitle, icon, color, opts \\ []) do
    handles =
      [
        Keyword.get(opts, :inputs, true) && Handle.target(:left),
        Keyword.get(opts, :outputs, true) && Handle.source(:right)
      ]
      |> Enum.filter(& &1)

    Node.new(
      id,
      %{x: x, y: y},
      %{title: title, subtitle: subtitle, icon: icon, color: color},
      Keyword.merge(
        [type: :card, handles: handles, z_index: 1],
        Keyword.drop(opts, [:inputs, :outputs])
      )
    )
  end

  @doc """
  A generated grid of nodes for the large flow demo.
  """
  def grid(count) do
    columns = max(round(:math.sqrt(count * 1.6)), 1)

    nodes =
      for i <- 0..(count - 1) do
        col = rem(i, columns)
        row = div(i, columns)

        Node.new("n#{i}", %{x: col * 220, y: row * 120}, %{label: "Node #{i}"},
          handles: [Handle.target(:left), Handle.source(:right)]
        )
      end

    edges =
      for i <- 0..(count - 1), rem(i + 1, columns) != 0, i + 1 < count do
        Edge.new("e#{i}", "n#{i}", "n#{i + 1}")
      end

    State.new(nodes: nodes, edges: edges)
  end

  @hierarchy [
    {"ceo", "Sofía Ramírez", "CEO", nil},
    {"cto", "Diego Fuentes", "CTO", "ceo"},
    {"cfo", "Ana Torres", "CFO", "ceo"},
    {"coo", "Lucas Pérez", "COO", "ceo"},
    {"eng-web", "Web team", "8 engineers", "cto"},
    {"eng-mobile", "Mobile team", "5 engineers", "cto"},
    {"eng-data", "Data team", "4 engineers", "cto"},
    {"finance", "Finance", "Accounting & payroll", "cfo"},
    {"legal", "Legal", "Contracts", "cfo"},
    {"ops-support", "Support", "24/7 help desk", "coo"},
    {"ops-logistics", "Logistics", "Warehouses", "coo"},
    {"web-frontend", "Frontend", "LiveView & Tailwind", "eng-web"},
    {"web-backend", "Backend", "Elixir & Postgres", "eng-web"},
    {"data-ml", "ML", "Recommendations", "eng-data"}
  ]

  @doc """
  A company hierarchy (tree) used by the layout examples. Nodes are placed at
  the origin: run a layout on it. Handles follow `direction` (`:tb` or `:lr`).
  """
  def hierarchy(direction \\ :tb) do
    nodes =
      Enum.map(@hierarchy, fn {id, title, subtitle, _parent} ->
        Node.new(id, %{x: 0, y: 0}, %{label: title, subtitle: subtitle},
          type: :person,
          width: 180,
          height: 56,
          handles: direction_handles(direction)
        )
      end)

    edges =
      for {id, _, _, parent} <- @hierarchy, parent do
        Edge.new("#{parent}->#{id}", parent, id,
          type: :smoothstep,
          marker_end: %{type: :arrow_closed}
        )
      end

    State.new(nodes: nodes, edges: edges)
  end

  @doc """
  Moves the handles of every node to match a layout direction.
  """
  def set_direction(%State{} = flow, direction) do
    handles = direction_handles(direction)
    %{flow | nodes: Map.new(flow.nodes, fn {id, node} -> {id, %{node | handles: handles}} end)}
  end

  defp direction_handles(:lr), do: [Handle.target(:left), Handle.source(:right)]
  defp direction_handles(_), do: [Handle.target(:top), Handle.source(:bottom)]
end
