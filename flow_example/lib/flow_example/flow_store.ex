defmodule FlowExample.FlowStore do
  @moduledoc """
  Shared in-memory flows, keyed by room (used by the collaborative example).
  """
  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  @doc """
  Returns the flow of `room`, creating it with `default_fun` the first time.
  """
  def get(room, default_fun) do
    Agent.get_and_update(__MODULE__, fn rooms ->
      case Map.fetch(rooms, room) do
        {:ok, flow} ->
          {flow, rooms}

        :error ->
          flow = default_fun.()
          {flow, Map.put(rooms, room, flow)}
      end
    end)
  end

  @doc """
  Applies `fun` to the flow of `room` and returns the new flow.
  """
  def update(room, fun) do
    Agent.get_and_update(__MODULE__, fn rooms ->
      case Map.fetch(rooms, room) do
        {:ok, flow} ->
          flow = fun.(flow)
          {flow, Map.put(rooms, room, flow)}

        :error ->
          {nil, rooms}
      end
    end)
  end

  @doc """
  Replaces the flow of `room`.
  """
  def put(room, flow), do: Agent.update(__MODULE__, &Map.put(&1, room, flow))
end
