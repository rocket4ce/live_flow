defmodule LiveFlow.PathsTest do
  use ExUnit.Case, async: true

  alias LiveFlow.Paths.{Smoothstep, Step}

  # Expected values generated with xyflow's getSmoothStepPath (@xyflow/system 0.0.83)
  describe "Smoothstep (xyflow parity)" do
    test "opposite handles bend at the midpoint by default" do
      assert %{
               path: "M0 20L 70,20Q 75,20 75,25L 75,95Q 75,100 80,100L150 100",
               label_x: 75.0,
               label_y: 60.0
             } = Smoothstep.path(0, 20, :right, 150, 100, :left)
    end

    test "step_position moves the bend towards the source" do
      assert %{path: "M0 20L 37,20Q 42,20 42,25L 42,95Q 42,100 47,100L150 100", label_x: 42.0} =
               Smoothstep.path(0, 20, :right, 150, 100, :left, step_position: 0.2)
    end

    test "vertical edges honor step_position and border_radius" do
      assert %{path: "M0 0L 0,130Q 0,140 10,140L 90,140Q 100,140 100,150L100 200"} =
               Smoothstep.path(0, 0, :bottom, 100, 200, :top,
                 step_position: 0.75,
                 border_radius: 10
               )
    end

    test "same side handles closer than the offset" do
      assert %{path: "M0 0L 25,0Q 30,0 30,5L 30,45Q 30,50 25,50L10 50"} =
               Smoothstep.path(0, 0, :right, 10, 50, :right)
    end

    test "mixed handle positions" do
      assert %{
               path:
                 "M0 0L 15,0Q 20,0 20,5L 20,115Q 20,120 25,120L 95,120Q 100,120 100,115L100 100"
             } =
               Smoothstep.path(0, 0, :right, 100, 100, :bottom)
    end

    test "every bend stays rounded at step_position 0 and 1" do
      for step <- [0, 1] do
        %{path: path} = Smoothstep.path(0, 0, :right, 200, 100, :left, step_position: step)
        bends = path |> String.split("Q") |> length()
        assert bends == 3, "expected 2 rounded bends for step_position #{step}, got: #{path}"
      end
    end
  end

  describe "Step" do
    test "uses square corners" do
      %{path: path} = Step.path(200, 0, :right, 0, 100, :left)
      refute path =~ "Q"
      assert path == "M200 0L220 0L220 50L-20 50L-20 100L0 100"
    end

    test "supports step_position" do
      assert %{path: "M0 0L40 0L40 100L200 100"} =
               Step.path(0, 0, :right, 200, 100, :left, step_position: 0.2, offset: 0)
    end
  end
end
