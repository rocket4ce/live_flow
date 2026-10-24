defmodule LiveFlow.Viewport.Culling do
  @moduledoc """
  Server-side viewport culling for LiveFlow.

  Filters nodes and edges to only render those visible within
  the current viewport, dramatically reducing DOM size for large flows.

  ## How It Works

  The viewport transform maps flow-space to screen-space:

      screen_x = flow_x * zoom + viewport.x
      screen_y = flow_y * zoom + viewport.y

  Inverting gives us the visible flow-space rectangle:

      flow_left   = -viewport.x / zoom
      flow_top    = -viewport.y / zoom
      flow_right  = (-viewport.x + container_width) / zoom
      flow_bottom = (-viewport.y + container_height) / zoom

  A node is visible if its bounding box overlaps this rectangle (with a margin).
  Unmeasured nodes use an estimated size (200x100) for the visibility check,
  so they render when near the viewport and get measured by JS on first appearance.

  When zoomed out far enough that more than `max_visible` nodes would be in view,
  nodes are sampled by proximity to the viewport center to cap DOM size.
  """

  alias LiveFlow.Viewport

  @default_margin 200
  @default_max_visible 500

  @doc """
  Computes the visible rectangle in flow-space coordinates.

  Returns `%{left: float, top: float, right: float, bottom: float}`.
  The margin (in flow-space pixels) extends the rectangle in all directions
  to preload nodes just outside the viewport for smooth panning.
  """
  @spec visible_rect(Viewport.t(), number(), number(), number()) :: map()
  def visible_rect(
        %Viewport{x: vx, y: vy, zoom: zoom},
        container_w,
        container_h,
        margin \\ @default_margin
      ) do
    zoom = max(zoom, 0.01)

    %{
      left: -vx / zoom - margin,
      top: -vy / zoom - margin,
      right: (-vx + container_w) / zoom + margin,
      bottom: (-vy + container_h) / zoom + margin
    }
  end

  @doc """
  Checks if a node is visible within the given flow-space rectangle.

  Unmeasured nodes use their position as a point check (with a generous
  default size estimate) so they only render when near the viewport.
  This prevents rendering thousands of off-screen unmeasured nodes at once.
  """
  @spec node_visible?(map(), map()) :: boolean()
  def node_visible?(node, rect) do
    pos = node.position

    if not node.measured or is_nil(node.width) or is_nil(node.height) do
      x2 = pos.x + 200
      y2 = pos.y + 100

      x2 >= rect.left and pos.x <= rect.right and
        y2 >= rect.top and pos.y <= rect.bottom
    else
      x2 = pos.x + node.width
      y2 = pos.y + node.height

      x2 >= rect.left and pos.x <= rect.right and
        y2 >= rect.top and pos.y <= rect.bottom
    end
  end

  @doc """
  Filters a list of nodes to only those visible in the viewport.

  Returns `{visible_nodes, visible_node_ids}` where `visible_node_ids`
  is a `MapSet` used for edge culling.

  When more than `max_visible` nodes fall within the viewport (e.g. when
  zoomed out very far), nodes closest to the viewport center are prioritized
  to cap DOM size and prevent browser freezes.
  """
  @spec cull_nodes(list(), Viewport.t(), number(), number(), keyword()) :: {list(), MapSet.t()}
  def cull_nodes(nodes, viewport, container_w, container_h, opts \\ []) do
    max_visible = Keyword.get(opts, :max_visible, @default_max_visible)
    rect = visible_rect(viewport, container_w, container_h)

    visible =
      Enum.filter(nodes, fn node ->
        node_visible?(node, rect)
      end)

    # Cap visible nodes to prevent browser crash on extreme zoom-out
    visible =
      if length(visible) > max_visible do
        center_x = (rect.left + rect.right) / 2
        center_y = (rect.top + rect.bottom) / 2

        visible
        |> Enum.sort_by(fn node ->
          pos = node.position
          dx = pos.x - center_x
          dy = pos.y - center_y
          dx * dx + dy * dy
        end)
        |> Enum.take(max_visible)
      else
        visible
      end

    visible_ids = MapSet.new(visible, & &1.id)

    {visible, visible_ids}
  end

  @doc """
  Filters a list of edges to only those with at least one visible endpoint.

  An edge is kept if its source OR target node is in the visible set.
  This prevents edges from "popping" in when both endpoints are just
  outside the viewport.
  """
  @spec cull_edges(list(), MapSet.t()) :: list()
  def cull_edges(edges, visible_node_ids) do
    Enum.filter(edges, fn edge ->
      MapSet.member?(visible_node_ids, edge.source) or
        MapSet.member?(visible_node_ids, edge.target)
    end)
  end
end
