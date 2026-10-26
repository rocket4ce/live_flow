defmodule LiveFlow.Components.NodeWrapperTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint LiveFlow.TestEndpoint

  defmodule StatusFlowLive do
    use Phoenix.LiveView

    alias LiveFlow.{Node, State}

    def mount(_params, session, socket) do
      owner = Map.get(session, "owner")
      node = Node.new("a", %{x: 0, y: 0}, %{status: "idle", owner: owner}, type: :status)
      fallback = Map.get(session, "fallback", false)
      {:ok, assign(socket, flow: State.new(nodes: [node]), fallback: fallback)}
    end

    def handle_info({:move, x}, socket) do
      flow =
        State.update_node(socket.assigns.flow, "a", fn node ->
          %{node | position: %{x: x, y: 0}}
        end)

      {:noreply, assign(socket, flow: flow)}
    end

    def handle_info({:status, status}, socket) do
      flow =
        State.update_node(socket.assigns.flow, "a", fn node ->
          %{node | data: %{node.data | status: status}}
        end)

      {:noreply, assign(socket, flow: flow)}
    end

    def render(assigns) do
      ~H"""
      <.live_component
        module={LiveFlow.Components.Flow}
        id="flow"
        flow={@flow}
        node_types={if @fallback, do: %{}, else: %{status: &status_node/1}}
        node_renderer={if @fallback, do: &status_node/1}
      />
      """
    end

    def status_node(assigns) do
      ~H"""
      <span id={"status-#{@node.id}"}>{@node.data.status}</span>
      <span>{report_render(@node.data.owner, @node.id)}</span>
      """
    end

    defp report_render(nil, _id), do: nil

    defp report_render(owner, id) do
      send(owner, {:rendered_id, id})
      nil
    end
  end

  for {name, session} <- [{"node_types", %{}}, {"node_renderer", %{"fallback" => true}}] do
    test "a function component in #{name} redraws when its node's data changes" do
      {:ok, view, _html} =
        live_isolated(build_conn(), StatusFlowLive, session: unquote(Macro.escape(session)))

      assert view |> element("#status-a") |> render() =~ "idle"

      send(view.pid, {:status, "running"})
      assert view |> element("#status-a") |> render() =~ "running"

      send(view.pid, {:move, 40})
      send(view.pid, {:status, "done"})
      assert view |> element("#status-a") |> render() =~ "done"
    end
  end

  test "a node data change re-evaluates only the parts of the template that read it" do
    {:ok, view, _html} =
      live_isolated(build_conn(), StatusFlowLive, session: %{"owner" => self()})

    # the dead render and the connected mount each draw the node once
    assert_receive {:rendered_id, "a"}
    assert_receive {:rendered_id, "a"}
    refute_received {:rendered_id, "a"}

    send(view.pid, {:status, "running"})
    assert view |> element("#status-a") |> render() =~ "running"
    refute_received {:rendered_id, "a"}
  end
end
