defmodule LiveFlow.EdgeTest do
  use ExUnit.Case, async: true

  alias LiveFlow.Edge

  describe "new/4" do
    test "creates an edge with defaults" do
      edge = Edge.new("e1", "node-a", "node-b")

      assert edge.id == "e1"
      assert edge.source == "node-a"
      assert edge.target == "node-b"
      assert edge.type == :bezier
      assert edge.animated == false
      assert edge.selected == false
      assert edge.selectable == true
      assert edge.deletable == true
      assert edge.hidden == false
      assert edge.source_handle == nil
      assert edge.target_handle == nil
      assert edge.label == nil
      assert edge.label_position == 0.5
      assert edge.label_style == %{}
      assert edge.marker_start == nil
      assert edge.marker_end == %{type: :arrow}
      assert edge.style == %{}
      assert edge.class == nil
      assert edge.z_index == 0
      assert edge.data == %{}
      assert edge.path_options == %{}
      assert edge.interaction_width == 20
    end

    test "creates an edge with custom options" do
      edge =
        Edge.new("e2", "a", "b",
          source_handle: "out-1",
          target_handle: "in-1",
          type: :straight,
          animated: true,
          selectable: false,
          deletable: false,
          label: "my edge",
          label_position: 0.3,
          label_style: %{"color" => "red"},
          marker_start: %{type: :arrow_closed},
          marker_end: %{type: :arrow, color: "blue"},
          style: %{"stroke" => "red"},
          class: "custom-edge",
          z_index: 10,
          data: %{weight: 5},
          path_options: %{curvature: 0.5}
        )

      assert edge.source_handle == "out-1"
      assert edge.target_handle == "in-1"
      assert edge.type == :straight
      assert edge.animated == true
      assert edge.selectable == false
      assert edge.deletable == false
      assert edge.label == "my edge"
      assert edge.label_position == 0.3
      assert edge.label_style == %{"color" => "red"}
      assert edge.marker_start == %{type: :arrow_closed}
      assert edge.marker_end == %{type: :arrow, color: "blue"}
      assert edge.style == %{"stroke" => "red"}
      assert edge.class == "custom-edge"
      assert edge.z_index == 10
      assert edge.data == %{weight: 5}
      assert edge.path_options == %{curvature: 0.5}
    end
  end

  describe "update/2" do
    test "updates edge attributes" do
      edge = Edge.new("e1", "a", "b")
      updated = Edge.update(edge, animated: true, label: "Updated")

      assert updated.animated == true
      assert updated.label == "Updated"
      assert updated.source == "a"
    end
  end

  describe "select/2" do
    test "selects an edge" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.select(edge).selected == true
      assert Edge.select(edge, true).selected == true
    end

    test "deselects an edge" do
      edge = Edge.new("e1", "a", "b") |> Edge.select()

      assert Edge.select(edge, false).selected == false
    end
  end

  describe "animate/2" do
    test "enables animation" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.animate(edge).animated == true
      assert Edge.animate(edge, true).animated == true
    end

    test "disables animation" do
      edge = Edge.new("e1", "a", "b") |> Edge.animate()

      assert Edge.animate(edge, false).animated == false
    end
  end

  describe "set_label/2" do
    test "sets a label" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.set_label(edge, "Hello").label == "Hello"
    end

    test "clears a label" do
      edge = Edge.new("e1", "a", "b", label: "Old")

      assert Edge.set_label(edge, nil).label == nil
    end
  end

  describe "connects_same_nodes?/2" do
    test "returns true for same direction" do
      e1 = Edge.new("e1", "a", "b")
      e2 = Edge.new("e2", "a", "b")

      assert Edge.connects_same_nodes?(e1, e2) == true
    end

    test "returns true for reverse direction" do
      e1 = Edge.new("e1", "a", "b")
      e2 = Edge.new("e2", "b", "a")

      assert Edge.connects_same_nodes?(e1, e2) == true
    end

    test "returns false for different nodes" do
      e1 = Edge.new("e1", "a", "b")
      e2 = Edge.new("e2", "a", "c")

      assert Edge.connects_same_nodes?(e1, e2) == false
    end

    test "returns false for completely different nodes" do
      e1 = Edge.new("e1", "a", "b")
      e2 = Edge.new("e2", "c", "d")

      assert Edge.connects_same_nodes?(e1, e2) == false
    end
  end

  describe "connects_to?/2" do
    test "returns true when node is source" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.connects_to?(edge, "a") == true
    end

    test "returns true when node is target" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.connects_to?(edge, "b") == true
    end

    test "returns false when node is neither source nor target" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.connects_to?(edge, "c") == false
    end
  end

  describe "effective_source_handle/1" do
    test "returns 'source' when source_handle is nil" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.effective_source_handle(edge) == "source"
    end

    test "returns the explicit source_handle" do
      edge = Edge.new("e1", "a", "b", source_handle: "out-1")

      assert Edge.effective_source_handle(edge) == "out-1"
    end
  end

  describe "effective_target_handle/1" do
    test "returns 'target' when target_handle is nil" do
      edge = Edge.new("e1", "a", "b")

      assert Edge.effective_target_handle(edge) == "target"
    end

    test "returns the explicit target_handle" do
      edge = Edge.new("e1", "a", "b", target_handle: "in-1")

      assert Edge.effective_target_handle(edge) == "in-1"
    end
  end
end
