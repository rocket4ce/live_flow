defmodule LiveFlow.Layout do
  @moduledoc """
  Helpers for preparing flow data for client-side auto-layout (ELK).
  """

  alias LiveFlow.State

  @default_width 150
  @default_height 50

  @doc """
  Prepares serializable layout data from the current flow state.

  Returns a map with `nodes` (list of id/width/height maps) and
  `edges` (list of id/source/target maps) suitable for sending
  to the client-side ELK layout engine via `push_event`.
  """
  @spec prepare_layout_data(State.t(), map()) :: map()
  def prepare_layout_data(%State{} = flow, opts \\ %{}) do
    nodes =
      flow.nodes
      |> Map.values()
      |> Enum.map(fn node ->
        %{
          id: node.id,
          width: node.width || @default_width,
          height: node.height || @default_height
        }
      end)

    edges =
      flow.edges
      |> Map.values()
      |> Enum.map(fn edge ->
        %{
          id: edge.id,
          source: edge.source,
          target: edge.target
        }
      end)

    %{
      nodes: nodes,
      edges: edges,
      direction: Map.get(opts, "direction", "DOWN")
    }
  end

  @doc """
  Prepares serializable layout data for the client-side tree layout algorithm.

  Similar to `prepare_layout_data/2` but outputs options compatible with
  the pure JS tree layout engine (direction: TB/LR, nodeSpacing, levelSpacing).
  """
  @spec prepare_tree_layout_data(State.t(), map()) :: map()
  def prepare_tree_layout_data(%State{} = flow, opts \\ %{}) do
    nodes =
      flow.nodes
      |> Map.values()
      |> Enum.map(fn node ->
        %{
          id: node.id,
          width: node.width || @default_width,
          height: node.height || @default_height
        }
      end)

    edges =
      flow.edges
      |> Map.values()
      |> Enum.map(fn edge ->
        %{
          id: edge.id,
          source: edge.source,
          target: edge.target
        }
      end)

    %{
      nodes: nodes,
      edges: edges,
      options: %{
        direction: Map.get(opts, "direction", "TB"),
        nodeSpacing: 80,
        levelSpacing: 120
      }
    }
  end
end
