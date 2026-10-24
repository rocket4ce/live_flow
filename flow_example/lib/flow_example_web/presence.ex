defmodule FlowExampleWeb.Presence do
  @moduledoc """
  Tracks the users of the collaborative example.
  """
  use Phoenix.Presence,
    otp_app: :flow_example,
    pubsub_server: FlowExample.PubSub
end
