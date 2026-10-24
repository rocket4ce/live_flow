defmodule FlowExampleWeb.Examples do
  @moduledoc """
  Registry of the showcase examples, mirroring the React Flow example
  catalog (https://reactflow.dev/examples), including the Pro examples.

  Routes, navigation and the gallery are generated from this list.
  Entries with `:path` reuse an existing page instead of a dedicated one.
  """

  @categories [
    overview: "Overview",
    nodes: "Nodes",
    edges: "Edges",
    interaction: "Interaction",
    grouping: "Subflows & Grouping",
    layout: "Layout",
    styling: "Styling",
    whiteboard: "Whiteboard",
    misc: "Misc"
  ]

  # {category, slug, title, description, pro?, module suffix | {:path, existing}}
  @entries [
    {:overview, "feature-overview", "Feature Overview",
     "The most used features: controls, minimap, node types, edge types, edge labels and custom styling.",
     false, "Overview.FeatureOverviewLive"},

    # Nodes
    {:nodes, "add-node-on-edge-drop", "Add Node On Edge Drop",
     "A new node appears wherever you drop the connection line.", false,
     "Nodes.AddNodeOnEdgeDropLive"},
    {:nodes, "connection-limit", "Connection Limit",
     "Limit the number of connections a handle can have.", false, "Nodes.ConnectionLimitLive"},
    {:nodes, "custom-node", "Custom Nodes", "Display any content inside of a node.", false,
     "Nodes.CustomNodeLive"},
    {:nodes, "delete-middle-node", "Delete Middle Node",
     "Remove a node without breaking the flow.", false, "Nodes.DeleteMiddleNodeLive"},
    {:nodes, "drag-handle", "Drag Handle", "Restrict dragging to a specific part of node.", false,
     "Nodes.DragHandleLive"},
    {:nodes, "easy-connect", "Easy Connect", "Make the whole node into a handle.", false,
     "Nodes.EasyConnectLive"},
    {:nodes, "intersections", "Intersections", "Detect when a node overlaps with another node.",
     false, "Nodes.IntersectionsLive"},
    {:nodes, "node-resizer", "Node Resizer",
     "Change the size of a node with a bounding box or draggable handles.", false,
     {:path, "/resizing"}},
    {:nodes, "node-toolbar", "Node Toolbar",
     "A toolbar with buttons appears next to the selected node.", false, "Nodes.NodeToolbarLive"},
    {:nodes, "proximity-connect", "Proximity Connect",
     "Automatically create edges when nodes get close to each other.", false,
     "Nodes.ProximityConnectLive"},
    {:nodes, "rotatable-node", "Rotatable Node",
     "A custom node that can be rotated using CSS transforms.", false, "Nodes.RotatableNodeLive"},
    {:nodes, "node-position-animation", "Node Position Animation",
     "Animate smooth transitions between different graph layouts.", true,
     "Nodes.NodePositionAnimationLive"},
    {:nodes, "stress", "Stress Test", "Render hundreds of nodes and edges at once.", false,
     {:path, "/large"}},
    {:nodes, "update-node", "Updating Nodes", "Update the data field of a specific node.", false,
     "Nodes.UpdateNodeLive"},
    {:nodes, "shapes", "Shapes", "Custom nodes with the shapes commonly used in flow charts.",
     true, "Nodes.ShapesLive"},

    # Edges
    {:edges, "animating-edges", "Animating Edges",
     "Edge animations that go beyond the built-in animated edge.", false,
     "Edges.AnimatingEdgesLive"},
    {:edges, "custom-connectionline", "Custom Connection Line",
     "Change the appearance and behavior of the connection line.", false,
     "Edges.CustomConnectionLineLive"},
    {:edges, "custom-edges", "Custom Edges",
     "Edges with special routing or controls along the edge.", false, "Edges.CustomEdgesLive"},
    {:edges, "delete-edge-on-drop", "Delete Edge on Drop",
     "Delete an edge when it doesn't find a handle.", false, "Edges.DeleteEdgeOnDropLive"},
    {:edges, "edge-label-renderer", "Edge Label Renderer",
     "Render edge labels as HTML on top of edges.", false, "Edges.EdgeLabelRendererLive"},
    {:edges, "edge-intersection", "Edge Intersection",
     "Detect edge intersections with nodes while dragging.", false, "Edges.EdgeIntersectionLive"},
    {:edges, "edge-toolbar", "Edge Toolbar", "Display content on top of an edge.", false,
     "Edges.EdgeToolbarLive"},
    {:edges, "edge-types", "Edge Types",
     "Make edges straight, stepped, smooth-stepped, or bezier curved.", false, {:path, "/edges"}},
    {:edges, "edge-routing", "Edge Routing", "Orthogonal edges routed around the nodes.", true,
     "Edges.EdgeRoutingLive"},
    {:edges, "floating-edges", "Floating Edges",
     "Instead of a fixed handle, edges attach to the closest point of the node.", false,
     "Edges.FloatingEdgesLive"},
    {:edges, "markers", "Edge Markers", "Make your edges into arrows, circles or custom markers.",
     false, "Edges.MarkersLive"},
    {:edges, "multi-connection-line", "Multi Connection Line",
     "Draw multiple connection lines at once from any selected nodes.", false,
     "Edges.MultiConnectionLineLive"},
    {:edges, "reconnect-edge", "Reconnect Edge",
     "Click-drag to move an existing edge from one handle to another.", false,
     "Edges.ReconnectEdgeLive"},
    {:edges, "simple-floating-edges", "Simple Floating Edges",
     "Edges connect to the closest available side.", false, "Edges.SimpleFloatingEdgesLive"},
    {:edges, "temporary-edges", "Temporary Edges",
     "Keep incomplete connections as temporary edges with a ghost node.", false,
     "Edges.TemporaryEdgesLive"},
    {:edges, "editable-edge", "Editable Edge",
     "A custom edge with draggable control points to change its path.", true,
     "Edges.EditableEdgeLive"},

    # Interaction
    {:interaction, "computing-flows", "Computing Flows",
     "Nodes compute their values from the nodes connected to them.", false,
     "Interaction.ComputingFlowsLive"},
    {:interaction, "connection-events", "Connection Events",
     "The events emitted during the connection process, in order.", false,
     "Interaction.ConnectionEventsLive"},
    {:interaction, "context-menu", "Context Menu",
     "Right-click a node to display custom actions.", false, "Interaction.ContextMenuLive"},
    {:interaction, "contextual-zoom", "Contextual Zoom",
     "Only display the content of a node when you are zoomed in close enough.", false,
     "Interaction.ContextualZoomLive"},
    {:interaction, "drag-and-drop", "Drag and Drop",
     "Drag and drop nodes from outside of the flow pane.", false, "Interaction.DragAndDropLive"},
    {:interaction, "prevent-cycles", "Preventing Cycles",
     "Check if a new connection would cause a cycle in the graph.", false,
     "Interaction.PreventCyclesLive"},
    {:interaction, "save-and-restore", "Save and Restore",
     "Save the state of the diagram and reload it after refreshing the page.", false,
     "Interaction.SaveAndRestoreLive"},
    {:interaction, "touch-device", "Touch Device",
     "Tap two handles to connect them, with bigger handles for small screens.", false,
     "Interaction.TouchDeviceLive"},
    {:interaction, "validation", "Validation",
     "Check if a new connection is valid and should be added.", false,
     "Interaction.ValidationLive"},
    {:interaction, "helper-lines", "Helper Lines",
     "Lines that help to align nodes, with automatic snapping.", true,
     "Interaction.HelperLinesLive"},
    {:interaction, "collaborative", "Collaborative",
     "A graph edited by multiple users at once, with live cursors (PubSub).", true,
     "Interaction.CollaborativeLive"},
    {:interaction, "copy-paste", "Copy and Paste",
     "Select nodes and edges to cut, copy, and paste.", true, "Interaction.CopyPasteLive"},
    {:interaction, "undo-redo", "Undo and Redo",
     "Undo and redo moving, adding, and deleting nodes and edges.", true,
     "Interaction.UndoRedoLive"},

    # Grouping
    {:grouping, "selection-grouping", "Selection Grouping",
     "Group the selected nodes into a parent node, and ungroup them again.", true,
     "Grouping.SelectionGroupingLive"},
    {:grouping, "parent-child-relation", "Parent Child Relation",
     "Attach and detach nodes from parent containers with drag and drop.", true,
     "Grouping.ParentChildRelationLive"},
    {:grouping, "sub-flows", "Sub Flow",
     "Nested graphs and group nodes, with child nodes kept inside their parent.", false,
     "Grouping.SubFlowsLive"},

    # Layout
    {:layout, "dagre", "Tree Layout",
     "Layered tree layout computed in Elixir (the dagre example).", false, "Layout.DagreLive"},
    {:layout, "elkjs", "Elkjs Tree", "Layout with elkjs, running in the browser.", false,
     "Layout.ElkjsLive"},
    {:layout, "elkjs-multiple-handles", "Elkjs Multiple Handles",
     "Use multiple handles with elkjs to reduce edge crossings.", false,
     "Layout.ElkjsMultipleHandlesLive"},
    {:layout, "horizontal", "Horizontal Flow", "A diagram that flows from left to right.", false,
     "Layout.HorizontalLive"},
    {:layout, "expand-collapse", "Expand and Collapse",
     "Hierarchical trees with expandable and collapsible nodes.", true,
     "Layout.ExpandCollapseLive"},
    {:layout, "auto-layout", "Auto Layout",
     "Nodes are arranged automatically whenever the graph changes.", true,
     "Layout.AutoLayoutLive"},
    {:layout, "force-layout", "Force Layout",
     "A force-directed layout where new nodes never overlap existing ones.", true,
     "Layout.ForceLayoutLive"},
    {:layout, "dynamic-layouting", "Dynamic Layouting",
     "A self-organizing graph where nodes are added through placeholders.", true,
     "Layout.DynamicLayoutingLive"},
    {:layout, "node-collisions", "Node Collisions", "Automatically resolve node overlaps.", false,
     "Layout.NodeCollisionsLive"},

    # Styling
    {:styling, "base-style", "Base Style", "The bare-bones base style without a theme.", false,
     "Styling.BaseStyleLive"},
    {:styling, "dark-mode", "Dark Mode", "Switch between dark, light and system mode.", false,
     "Styling.DarkModeLive"},
    {:styling, "tailwind", "Tailwind", "Style nodes and edges with Tailwind classes.", false,
     "Styling.TailwindLive"},
    {:styling, "turbo-flow", "Turbo Flow", "Nodes with glowing animated gradient borders.", false,
     "Styling.TurboFlowLive"},

    # Whiteboard
    {:whiteboard, "eraser", "Eraser Tool", "Delete nodes and edges by wiping over them.", false,
     "Whiteboard.EraserLive"},
    {:whiteboard, "lasso-selection", "Lasso Selection",
     "Select multiple items by drawing a lasso.", false, "Whiteboard.LassoSelectionLive"},
    {:whiteboard, "rectangle", "Rectangle", "Draw rectangles on a whiteboard.", false,
     "Whiteboard.RectangleLive"},
    {:whiteboard, "freehand-draw", "Freehand Draw", "Freehand drawing on the canvas.", true,
     "Whiteboard.FreehandDrawLive"},

    # Misc
    {:misc, "download-image", "Download Image", "Save the flow as a PNG or SVG image.", false,
     "Misc.DownloadImageLive"},
    {:misc, "server-side-image-creation", "Server Side Image Creation",
     "Generate static SVG images of a flow on the server, without a browser.", true,
     "Misc.ServerSideImageLive"}
  ]

  @examples Enum.map(@entries, fn {category, slug, title, description, pro, target} ->
              {module, path, existing} =
                case target do
                  {:path, path} ->
                    {nil, path, true}

                  suffix ->
                    {Module.concat(FlowExampleWeb.Examples, suffix),
                     "/examples/#{category}/#{slug}", false}
                end

              %{
                id: "#{category}/#{slug}",
                category: category,
                slug: slug,
                title: title,
                description: description,
                pro: pro,
                module: module,
                path: path,
                existing: existing,
                reactflow_url:
                  if(category == :overview,
                    do: "https://reactflow.dev/examples/overview",
                    else: "https://reactflow.dev/examples/#{category}/#{slug}"
                  )
              }
            end)

  @doc "All examples."
  def all, do: @examples

  @doc "Examples with a dedicated LiveView (used to generate routes)."
  def routed, do: Enum.reject(@examples, & &1.existing)

  @doc "`[{category, label, examples}]` in display order."
  def by_category do
    Enum.map(@categories, fn {category, label} ->
      {category, label, Enum.filter(@examples, &(&1.category == category))}
    end)
  end

  @doc "The example rendered by a LiveView module."
  def for_module(module), do: Enum.find(@examples, &(&1.module == module))

  @doc "The example served at `path`."
  def for_path(path), do: Enum.find(@examples, &(&1.path == path))

  @doc "Path of the LiveView source file on GitHub."
  def source_url(%{module: nil}), do: nil

  def source_url(%{module: module}) do
    file =
      module
      |> Module.split()
      |> Enum.drop(1)
      |> Enum.map_join("/", &Macro.underscore/1)

    "https://github.com/rocket4ce/live_flow/blob/main/flow_example/lib/flow_example_web/live/#{file}.ex"
  end
end
