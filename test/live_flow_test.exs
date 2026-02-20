defmodule LiveFlowTest do
  use ExUnit.Case
  doctest LiveFlow

  test "greets the world" do
    assert LiveFlow.hello() == :world
  end
end
