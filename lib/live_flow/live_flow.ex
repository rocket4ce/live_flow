defmodule LiveFlow do
  @moduledoc """
  LiveFlow - A Phoenix LiveView library for building interactive node-based diagrams.

  LiveFlow provides components and utilities for creating flow diagrams similar to
  React Flow or Svelte Flow, but using Phoenix LiveView and LiveComponents.

  ## Quick Start

      # In your LiveView
      defmodule MyAppWeb.FlowLive do
        use MyAppWeb, :live_view

        alias LiveFlow.{State, Node, Edge}

        def mount(_params, _session, socket) do
          flow = State.new(
            nodes: [
              Node.new("1", %{x: 100, y: 100}, %{label: "Start"}),
              Node.new("2", %{x: 300, y: 200}, %{label: "End"})
            ],
            edges: [
              Edge.new("e1", "1", "2")
            ]
          )

          {:ok, assign(socket, flow: flow)}
        end

        def render(assigns) do
          ~H\"\"\"
          <.live_component
            module={LiveFlow.Components.Flow}
            id="my-flow"
            flow={@flow}
            opts={%{controls: true, background: :dots}}
          />
          \"\"\"
        end
      end

  ## Components

    * `LiveFlow.Components.Flow` - Main flow container component
    * `LiveFlow.Components.NodeWrapper` - Node wrapper component
    * `LiveFlow.Components.Edge` - Edge rendering component
    * `LiveFlow.Components.Handle` - Handle component for connections

  ## Data Structures

    * `LiveFlow.Node` - Node struct
    * `LiveFlow.Edge` - Edge struct
    * `LiveFlow.Handle` - Handle struct
    * `LiveFlow.Viewport` - Viewport (pan/zoom) state
    * `LiveFlow.State` - Main state container

  ## Path Types

    * `LiveFlow.Paths.Bezier` - Smooth curved paths
    * `LiveFlow.Paths.Straight` - Direct lines
    * `LiveFlow.Paths.Step` - Orthogonal paths with 90° turns
    * `LiveFlow.Paths.Smoothstep` - Orthogonal paths with rounded corners
  """

  # Re-export main modules for convenience
  defdelegate new_state(opts \\ []), to: LiveFlow.State, as: :new
  defdelegate new_node(id, position, data, opts \\ []), to: LiveFlow.Node, as: :new
  defdelegate new_edge(id, source, target, opts \\ []), to: LiveFlow.Edge, as: :new
  defdelegate new_handle(type, position, opts \\ []), to: LiveFlow.Handle, as: :new

  @doc """
  Creates a new flow state with the given nodes and edges.

  ## Examples

      iex> LiveFlow.create_flow(
      ...>   nodes: [
      ...>     %{id: "1", position: %{x: 0, y: 0}, data: %{label: "A"}},
      ...>     %{id: "2", position: %{x: 100, y: 100}, data: %{label: "B"}}
      ...>   ],
      ...>   edges: [
      ...>     %{id: "e1", source: "1", target: "2"}
      ...>   ]
      ...> )
  """
  @spec create_flow(keyword()) :: LiveFlow.State.t()
  def create_flow(opts \\ []) do
    nodes =
      opts
      |> Keyword.get(:nodes, [])
      |> Enum.map(&map_to_node/1)

    edges =
      opts
      |> Keyword.get(:edges, [])
      |> Enum.map(&map_to_edge/1)

    LiveFlow.State.new(nodes: nodes, edges: edges)
  end

  defp map_to_node(%LiveFlow.Node{} = node), do: node

  defp map_to_node(map) when is_map(map) do
    id = Map.get(map, :id) || Map.get(map, "id")
    position = Map.get(map, :position) || Map.get(map, "position") || %{x: 0, y: 0}
    data = Map.get(map, :data) || Map.get(map, "data") || %{}

    opts = [
      type: get_atom(map, :type, :default),
      draggable: Map.get(map, :draggable, true),
      connectable: Map.get(map, :connectable, true),
      selectable: Map.get(map, :selectable, true),
      deletable: Map.get(map, :deletable, true)
    ]

    LiveFlow.Node.new(id, position, data, opts)
  end

  defp map_to_edge(%LiveFlow.Edge{} = edge), do: edge

  defp map_to_edge(map) when is_map(map) do
    id = Map.get(map, :id) || Map.get(map, "id")
    source = Map.get(map, :source) || Map.get(map, "source")
    target = Map.get(map, :target) || Map.get(map, "target")

    opts = [
      source_handle: Map.get(map, :source_handle) || Map.get(map, "source_handle"),
      target_handle: Map.get(map, :target_handle) || Map.get(map, "target_handle"),
      type: get_atom(map, :type, :bezier),
      animated: Map.get(map, :animated, false),
      label: Map.get(map, :label) || Map.get(map, "label")
    ]

    LiveFlow.Edge.new(id, source, target, opts)
  end

  defp get_atom(map, key, default) do
    value = Map.get(map, key) || Map.get(map, Atom.to_string(key))

    cond do
      is_nil(value) -> default
      is_atom(value) -> value
      is_binary(value) -> String.to_existing_atom(value)
      true -> default
    end
  rescue
    ArgumentError -> default
  end
end
