defmodule FlowExample.Repo do
  use Ecto.Repo,
    otp_app: :flow_example,
    adapter: Ecto.Adapters.Postgres
end
