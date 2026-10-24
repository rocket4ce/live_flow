defmodule LiveFlow.XyflowParityTest do
  @moduledoc """
  Behaviour ported from recent xyflow releases (12.10 – 12.12).
  """
  use ExUnit.Case, async: true

  alias LiveFlow.{Edge, Node, State, Viewport}
  alias LiveFlow.Validation.Connection

  doctest LiveFlow.State, only: [bounds: 2]
  doctest LiveFlow.Viewport, only: [snap: 2, screen_to_flow: 4]

  defp node(id, x, y, opts \\ []), do: Node.new(id, %{x: x, y: y}, %{}, opts)

  describe "State.bounds/2" do
    setup do
      state =
        State.new(
          nodes: [
            node("a", 100, 100, width: 100, height: 50),
            node("b", 400, 300, width: 50, height: 50),
            node("hidden", -500, -500, width: 20, height: 20, hidden: true)
          ]
        )

      %{state: state}
    end

    test "ignores hidden nodes by default", %{state: state} do
      assert State.bounds(state) == %{x: 100, y: 100, width: 350, height: 250}
    end

    test "include_hidden uses the intrinsic size of hidden nodes (xyflow 56cf3b0)", %{
      state: state
    } do
      assert State.bounds(state, include_hidden: true) == %{
               x: -500,
               y: -500,
               width: 950,
               height: 850
             }
    end

    test "unknown ids don't stretch the bounds to the origin (xyflow e5d86bd)", %{state: state} do
      assert State.bounds(state, nodes: ["b", "nope"]) == %{x: 400, y: 300, width: 50, height: 50}
      assert State.bounds(state, nodes: ["nope"]) == nil
    end

    test "returns nil when every node is hidden" do
      assert State.bounds(State.new(nodes: [node("h", 10, 10, hidden: true)])) == nil
    end
  end

  describe "State.reconnect_edge/3" do
    setup do
      state =
        State.new(
          nodes: [node("a", 0, 0), node("b", 100, 0), node("c", 200, 0)],
          edges: [Edge.new("e1", "a", "b", source_handle: "out", target_handle: "in")]
        )

      %{state: state}
    end

    test "moves the target end", %{state: state} do
      params = %{"edge_id" => "e1", "end" => "target", "node_id" => "c", "handle_id" => "in-2"}
      edge = state |> State.reconnect_edge(params) |> State.get_edge("e1")

      assert edge.source == "a"
      assert edge.target == "c"
      assert edge.target_handle == "in-2"
    end

    test "moves the source end", %{state: state} do
      params = %{"edge_id" => "e1", "end" => "source", "node_id" => "c", "handle_id" => nil}
      edge = state |> State.reconnect_edge(params) |> State.get_edge("e1")

      assert edge.source == "c"
      assert edge.source_handle == nil
      assert edge.target == "b"
    end

    test "can replace the id with a custom function", %{state: state} do
      params = %{"edge_id" => "e1", "end" => "target", "node_id" => "c", "handle_id" => nil}

      state =
        State.reconnect_edge(state, params,
          replace_id: true,
          edge_id: fn edge -> "#{edge.source}-#{edge.target}" end
        )

      assert State.get_edge(state, "e1") == nil
      assert %Edge{source: "a", target: "c"} = State.get_edge(state, "a-c")
    end

    test "ignores unknown edges and nodes", %{state: state} do
      assert State.reconnect_edge(state, %{"edge_id" => "x", "end" => "target", "node_id" => "c"}) ==
               state

      assert State.reconnect_edge(state, %{"edge_id" => "e1", "end" => "target", "node_id" => "x"}) ==
               state
    end
  end

  describe "Connection.validate_and_create/3 :edge_id (xyflow 8598b6bc2)" do
    setup do
      %{state: State.new(nodes: [node("a", 0, 0), node("b", 100, 0)])}
    end

    test "accepts a custom id function", %{state: state} do
      params = %{
        "source" => "a",
        "target" => "b",
        "source_handle" => "out",
        "target_handle" => nil
      }

      assert {:ok, %Edge{id: "a:out->b"}} =
               Connection.validate_and_create(state, params,
                 edge_id: fn conn -> "#{conn.source}:#{conn.source_handle}->#{conn.target}" end
               )
    end

    test "accepts a fixed id", %{state: state} do
      assert {:ok, %Edge{id: "custom"}} =
               Connection.validate_and_create(state, %{"source" => "a", "target" => "b"},
                 edge_id: "custom"
               )
    end

    test "generates an id by default", %{state: state} do
      assert {:ok, %Edge{id: "e-" <> _}} =
               Connection.validate_and_create(state, %{"source" => "a", "target" => "b"})
    end
  end

  describe "Viewport.screen_to_flow/4 snapping (xyflow 8c9b7e726)" do
    test "snaps to a custom grid after converting" do
      vp = Viewport.new(x: 100, y: 50, zoom: 2.0)

      assert Viewport.screen_to_flow(vp, 142, 96, snap_to_grid: true, snap_grid: {10, 10}) ==
               {20.0, 20.0}
    end
  end

  describe "Node options" do
    test "accepts explicit size, hidden and drag_handle" do
      node = node("a", 0, 0, width: 120, height: 60, hidden: true, drag_handle: ".grip")
      assert %Node{width: 120, height: 60, hidden: true, drag_handle: ".grip"} = node
    end

    test "serializer round-trips hidden, resizable and drag_handle" do
      state =
        State.new(
          nodes: [
            node("a", 0, 0, hidden: true, drag_handle: ".grip"),
            node("b", 10, 10, resizable: true, width: 300, height: 200)
          ]
        )

      {:ok, restored} = state |> LiveFlow.Serializer.to_json() |> LiveFlow.Serializer.from_json()

      assert %Node{hidden: true, drag_handle: ".grip"} = State.get_node(restored, "a")
      assert %Node{resizable: true, width: 300, height: 200} = State.get_node(restored, "b")
    end
  end

  describe "default handle ids" do
    setup do
      %{
        state:
          State.new(nodes: [node("a", 0, 0), node("b", 100, 0)], edges: [Edge.new("e", "a", "b")])
      }
    end

    test "edges without handle ids match the client's default ids", %{state: state} do
      params = %{source: "a", target: "b", source_handle: "source", target_handle: "target"}

      assert State.edge_exists?(state, "a", "b", "source", "target")
      assert {:error, _} = LiveFlow.Validation.no_duplicate_edges(state, params)
      assert {:error, _} = LiveFlow.Validation.max_connections(state, params, max: 1)
    end

    test "max_connections can limit a single side", %{state: state} do
      params = %{source: "a", target: "other", source_handle: "source", target_handle: "target"}

      assert {:error, _} = LiveFlow.Validation.max_connections(state, params, max: 1)
      assert :ok = LiveFlow.Validation.max_connections(state, params, max: 1, side: :target)
    end
  end
end
