defmodule LiveFlow.NodeTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{Node, Handle}

  describe "new/4" do
    test "creates a node with defaults" do
      node = Node.new("n1", %{x: 100, y: 200}, %{label: "Hello"})

      assert node.id == "n1"
      assert node.position == %{x: 100.0, y: 200.0}
      assert node.data == %{label: "Hello"}
      assert node.type == :default
      assert node.draggable == true
      assert node.connectable == true
      assert node.selectable == true
      assert node.deletable == true
      assert node.hidden == false
      assert node.dragging == false
      assert node.resizing == false
      assert node.selected == false
      assert node.measured == false
      assert node.width == nil
      assert node.height == nil
      assert node.parent_id == nil
      assert node.extent == nil
      assert node.style == %{}
      assert node.class == nil
      assert node.z_index == 0
      assert node.handles == []
    end

    test "creates a node with empty data by default" do
      node = Node.new("n1", %{x: 0, y: 0})

      assert node.data == %{}
    end

    test "creates a node with custom options" do
      handle = Handle.new(:source, :bottom, id: "out")

      node =
        Node.new("n2", %{x: 50, y: 75}, %{label: "Custom"},
          type: :input,
          draggable: false,
          connectable: false,
          selectable: false,
          deletable: false,
          parent_id: "parent-1",
          extent: :parent,
          style: %{"color" => "red"},
          class: "my-class",
          z_index: 5,
          handles: [handle]
        )

      assert node.type == :input
      assert node.draggable == false
      assert node.connectable == false
      assert node.selectable == false
      assert node.deletable == false
      assert node.parent_id == "parent-1"
      assert node.extent == :parent
      assert node.style == %{"color" => "red"}
      assert node.class == "my-class"
      assert node.z_index == 5
      assert node.handles == [handle]
    end

    test "normalizes integer position to float" do
      node = Node.new("n1", %{x: 10, y: 20}, %{})

      assert node.position == %{x: 10.0, y: 20.0}
    end

    test "normalizes string-keyed position" do
      node = Node.new("n1", %{"x" => 30, "y" => 40}, %{})

      assert node.position == %{x: 30.0, y: 40.0}
    end
  end

  describe "update/2" do
    test "updates position with normalization" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})
      updated = Node.update(node, position: %{x: 100, y: 200})

      assert updated.position == %{x: 100.0, y: 200.0}
    end

    test "updates other attributes" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})
      updated = Node.update(node, type: :output, draggable: false, z_index: 3)

      assert updated.type == :output
      assert updated.draggable == false
      assert updated.z_index == 3
    end

    test "preserves unmodified fields" do
      node = Node.new("n1", %{x: 10, y: 20}, %{label: "Keep"})
      updated = Node.update(node, type: :custom)

      assert updated.position == %{x: 10.0, y: 20.0}
      assert updated.data == %{label: "Keep"}
    end
  end

  describe "move/2" do
    test "moves node to a new position" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})
      moved = Node.move(node, %{x: 50, y: 75})

      assert moved.position == %{x: 50.0, y: 75.0}
    end

    test "normalizes string-keyed position on move" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})
      moved = Node.move(node, %{"x" => 100, "y" => 200})

      assert moved.position == %{x: 100.0, y: 200.0}
    end
  end

  describe "move_by/3" do
    test "moves node by delta offset" do
      node = Node.new("n1", %{x: 100, y: 100}, %{})
      moved = Node.move_by(node, 10, -20)

      assert moved.position == %{x: 110.0, y: 80.0}
    end

    test "works with float deltas" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})
      moved = Node.move_by(node, 1.5, 2.5)

      assert moved.position == %{x: 1.5, y: 2.5}
    end
  end

  describe "select/2" do
    test "selects a node" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})

      assert Node.select(node).selected == true
      assert Node.select(node, true).selected == true
    end

    test "deselects a node" do
      node = Node.new("n1", %{x: 0, y: 0}, %{}) |> Node.select()

      assert Node.select(node, false).selected == false
    end
  end

  describe "set_dimensions/3" do
    test "sets width, height, and marks as measured" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})

      assert node.measured == false

      measured = Node.set_dimensions(node, 200, 100)

      assert measured.width == 200
      assert measured.height == 100
      assert measured.measured == true
    end
  end

  describe "set_dragging/2" do
    test "sets dragging state" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})

      assert Node.set_dragging(node, true).dragging == true
      assert Node.set_dragging(node, false).dragging == false
    end
  end

  describe "bounds/1" do
    test "returns nil when not measured" do
      node = Node.new("n1", %{x: 100, y: 200}, %{})

      assert Node.bounds(node) == nil
    end

    test "returns correct bounds when measured" do
      node =
        Node.new("n1", %{x: 100, y: 200}, %{})
        |> Node.set_dimensions(150, 80)

      bounds = Node.bounds(node)

      assert bounds.x == 100.0
      assert bounds.y == 200.0
      assert bounds.width == 150
      assert bounds.height == 80
      assert bounds.x2 == 250.0
      assert bounds.y2 == 280.0
    end
  end

  describe "center/1" do
    test "returns nil when not measured" do
      node = Node.new("n1", %{x: 100, y: 200}, %{})

      assert Node.center(node) == nil
    end

    test "returns correct center when measured" do
      node =
        Node.new("n1", %{x: 100, y: 200}, %{})
        |> Node.set_dimensions(200, 100)

      center = Node.center(node)

      assert center.x == 200.0
      assert center.y == 250.0
    end
  end

  describe "contains_point?/3" do
    test "returns false when not measured" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})

      assert Node.contains_point?(node, 5, 5) == false
    end

    test "returns true when point is inside bounds" do
      node =
        Node.new("n1", %{x: 100, y: 100}, %{})
        |> Node.set_dimensions(200, 100)

      assert Node.contains_point?(node, 150, 150) == true
      # top-left corner (edge)
      assert Node.contains_point?(node, 100, 100) == true
      # bottom-right corner (edge)
      assert Node.contains_point?(node, 300, 200) == true
    end

    test "returns false when point is outside bounds" do
      node =
        Node.new("n1", %{x: 100, y: 100}, %{})
        |> Node.set_dimensions(200, 100)

      assert Node.contains_point?(node, 50, 50) == false
      assert Node.contains_point?(node, 301, 150) == false
      assert Node.contains_point?(node, 150, 201) == false
    end
  end

  describe "add_handle/2" do
    test "adds a handle to the node" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})
      handle = Handle.new(:source, :bottom)
      node = Node.add_handle(node, handle)

      assert length(node.handles) == 1
      assert hd(node.handles).type == :source
      assert hd(node.handles).position == :bottom
    end

    test "appends handles in order" do
      node = Node.new("n1", %{x: 0, y: 0}, %{})
      h1 = Handle.new(:source, :bottom, id: "out")
      h2 = Handle.new(:target, :top, id: "in")

      node = node |> Node.add_handle(h1) |> Node.add_handle(h2)

      assert length(node.handles) == 2
      assert Enum.at(node.handles, 0).id == "out"
      assert Enum.at(node.handles, 1).id == "in"
    end
  end
end
