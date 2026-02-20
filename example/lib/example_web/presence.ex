defmodule ExampleWeb.Presence do
  @moduledoc """
  Phoenix Presence module for tracking connected users in real-time flows.
  """

  use Phoenix.Presence,
    otp_app: :example,
    pubsub_server: Example.PubSub
end
