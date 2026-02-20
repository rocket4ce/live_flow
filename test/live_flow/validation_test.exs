defmodule LiveFlow.ValidationTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{Validation, State, Node, Edge, Handle}

  defp make_node(id, opts \\ []) do
    Node.new(id, %{x: 0, y: 0}, %{}, opts)
  end

  defp make_edge(id, source, target, opts \\ []) do
    Edge.new(id, source, target, opts)
  end

  defp conn_params(source, target, source_handle \\ nil, target_handle \\ nil) do
    %{
      source: source,
      target: target,
      source_handle: source_handle,
      target_handle: target_handle
    }
  end

  defp base_flow do
    State.new(
      nodes: [make_node("n1"), make_node("n2"), make_node("n3")],
      edges: []
    )
  end

  describe "validate/3" do
    test "returns :ok when all validators pass" do
      flow = base_flow()
      params = conn_params("n1", "n2")

      validators = [
        &Validation.no_duplicate_edges/2,
        &Validation.nodes_exist/2
      ]

      assert Validation.validate(flow, params, validators) == :ok
    end

    test "short-circuits on first failure" do
      flow = base_flow()
      params = conn_params("n1", "nonexistent")

      call_count = :counters.new(1, [:atomics])

      validators = [
        &Validation.nodes_exist/2,
        fn _flow, _params ->
          :counters.add(call_count, 1, 1)
          :ok
        end
      ]

      assert {:error, _} = Validation.validate(flow, params, validators)
      assert :counters.get(call_count, 1) == 0
    end

    test "returns :ok with empty validators list" do
      flow = base_flow()
      params = conn_params("n1", "n2")

      assert Validation.validate(flow, params, []) == :ok
    end
  end

  describe "preset/1" do
    test ":default returns no_duplicate_edges and nodes_exist" do
      validators = Validation.preset(:default)

      assert length(validators) == 2
    end

    test ":strict includes handles_valid" do
      validators = Validation.preset(:strict)

      assert length(validators) == 3
    end

    test ":default preset works end-to-end" do
      flow = base_flow()
      params = conn_params("n1", "n2")

      assert Validation.validate(flow, params, Validation.preset(:default)) == :ok
    end

    test ":default preset rejects duplicate" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2"))

      params = conn_params("n1", "n2")

      assert {:error, "Connection already exists"} =
               Validation.validate(flow, params, Validation.preset(:default))
    end
  end

  describe "no_duplicate_edges/2" do
    test "allows new connection" do
      flow = base_flow()
      params = conn_params("n1", "n2")

      assert Validation.no_duplicate_edges(flow, params) == :ok
    end

    test "rejects duplicate connection" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2"))

      params = conn_params("n1", "n2")

      assert {:error, "Connection already exists"} =
               Validation.no_duplicate_edges(flow, params)
    end

    test "allows same nodes with different handles" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2", source_handle: "out-1", target_handle: "in-1"))

      params = conn_params("n1", "n2", "out-2", "in-2")

      assert Validation.no_duplicate_edges(flow, params) == :ok
    end

    test "rejects duplicate with matching handles" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2", source_handle: "out", target_handle: "in"))

      params = conn_params("n1", "n2", "out", "in")

      assert {:error, "Connection already exists"} =
               Validation.no_duplicate_edges(flow, params)
    end
  end

  describe "nodes_exist/2" do
    test "passes when both nodes exist" do
      flow = base_flow()
      params = conn_params("n1", "n2")

      assert Validation.nodes_exist(flow, params) == :ok
    end

    test "fails when source node missing" do
      flow = base_flow()
      params = conn_params("missing", "n2")

      assert {:error, "Source node not found"} = Validation.nodes_exist(flow, params)
    end

    test "fails when target node missing" do
      flow = base_flow()
      params = conn_params("n1", "missing")

      assert {:error, "Target node not found"} = Validation.nodes_exist(flow, params)
    end
  end

  describe "no_cycles/2" do
    test "allows connection in a DAG" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2"))

      params = conn_params("n2", "n3")

      assert Validation.no_cycles(flow, params) == :ok
    end

    test "rejects connection that would create a cycle" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2"))
        |> State.add_edge(make_edge("e2", "n2", "n3"))

      # n3 -> n1 would create a cycle: n1 -> n2 -> n3 -> n1
      params = conn_params("n3", "n1")

      assert {:error, "Connection would create a cycle"} =
               Validation.no_cycles(flow, params)
    end

    test "allows connection between unconnected nodes" do
      flow = base_flow()
      params = conn_params("n1", "n3")

      assert Validation.no_cycles(flow, params) == :ok
    end

    test "rejects direct self-loop (a->b then b->a)" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2"))

      params = conn_params("n2", "n1")

      assert {:error, "Connection would create a cycle"} =
               Validation.no_cycles(flow, params)
    end

    test "allows parallel paths (diamond DAG)" do
      n4 = make_node("n4")

      flow =
        base_flow()
        |> State.add_node(n4)
        |> State.add_edge(make_edge("e1", "n1", "n2"))
        |> State.add_edge(make_edge("e2", "n1", "n3"))

      # n2 -> n4 and n3 -> n4 form a diamond, no cycle
      flow = State.add_edge(flow, make_edge("e3", "n2", "n4"))
      params = conn_params("n3", "n4")

      assert Validation.no_cycles(flow, params) == :ok
    end
  end

  describe "max_connections/3" do
    test "allows connection under the limit" do
      flow = base_flow()
      params = conn_params("n1", "n2")

      assert Validation.max_connections(flow, params, max: 2) == :ok
    end

    test "rejects when source handle exceeds limit" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2"))

      params = conn_params("n1", "n3")

      assert {:error, msg} = Validation.max_connections(flow, params, max: 1)
      assert String.contains?(msg, "Source handle")
    end

    test "rejects when target handle exceeds limit" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2"))

      params = conn_params("n3", "n2")

      assert {:error, msg} = Validation.max_connections(flow, params, max: 1)
      assert String.contains?(msg, "Target handle")
    end

    test "respects specific handle matching" do
      flow =
        base_flow()
        |> State.add_edge(make_edge("e1", "n1", "n2", source_handle: "out-1"))

      # Different source handle, should be under limit
      params = conn_params("n1", "n3", "out-2", nil)

      assert Validation.max_connections(flow, params, max: 1) == :ok
    end
  end

  describe "handles_valid/2" do
    test "passes when handles exist and are connectable" do
      h_source = Handle.new(:source, :bottom, id: "out")
      h_target = Handle.new(:target, :top, id: "in")

      flow =
        State.new(
          nodes: [
            make_node("n1", handles: [h_source]),
            make_node("n2", handles: [h_target])
          ]
        )

      params = conn_params("n1", "n2", "out", "in")

      assert Validation.handles_valid(flow, params) == :ok
    end

    test "fails when source handle not found" do
      h_target = Handle.new(:target, :top, id: "in")

      flow =
        State.new(
          nodes: [
            make_node("n1"),
            make_node("n2", handles: [h_target])
          ]
        )

      params = conn_params("n1", "n2", "missing-handle", "in")

      assert {:error, msg} = Validation.handles_valid(flow, params)
      assert String.contains?(msg, "not found")
    end

    test "fails when handle is not connectable" do
      h_source = Handle.new(:source, :bottom, id: "out", connectable: false)
      h_target = Handle.new(:target, :top, id: "in")

      flow =
        State.new(
          nodes: [
            make_node("n1", handles: [h_source]),
            make_node("n2", handles: [h_target])
          ]
        )

      params = conn_params("n1", "n2", "out", "in")

      assert {:error, msg} = Validation.handles_valid(flow, params)
      assert String.contains?(msg, "not connectable")
    end
  end

  describe "types_compatible/2" do
    test "passes when both handle types match" do
      h_source = Handle.new(:source, :bottom, id: "out", connect_type: :data)
      h_target = Handle.new(:target, :top, id: "in", connect_type: :data)

      flow =
        State.new(
          nodes: [
            make_node("n1", handles: [h_source]),
            make_node("n2", handles: [h_target])
          ]
        )

      params = conn_params("n1", "n2", "out", "in")

      assert Validation.types_compatible(flow, params) == :ok
    end

    test "passes when one handle has nil connect_type" do
      h_source = Handle.new(:source, :bottom, id: "out", connect_type: :data)
      h_target = Handle.new(:target, :top, id: "in")

      flow =
        State.new(
          nodes: [
            make_node("n1", handles: [h_source]),
            make_node("n2", handles: [h_target])
          ]
        )

      params = conn_params("n1", "n2", "out", "in")

      assert Validation.types_compatible(flow, params) == :ok
    end

    test "fails when types are incompatible" do
      h_source = Handle.new(:source, :bottom, id: "out", connect_type: :data)
      h_target = Handle.new(:target, :top, id: "in", connect_type: :control)

      flow =
        State.new(
          nodes: [
            make_node("n1", handles: [h_source]),
            make_node("n2", handles: [h_target])
          ]
        )

      params = conn_params("n1", "n2", "out", "in")

      assert {:error, msg} = Validation.types_compatible(flow, params)
      assert String.contains?(msg, "Incompatible types")
    end
  end
end
