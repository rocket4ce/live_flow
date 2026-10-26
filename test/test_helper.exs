Application.put_env(:live_flow, LiveFlow.TestEndpoint,
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "live_flow_test"]
)

{:ok, _} = LiveFlow.TestEndpoint.start_link()

ExUnit.start()
