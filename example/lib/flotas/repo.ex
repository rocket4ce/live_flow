defmodule Flotas.Repo do
  use Ecto.Repo,
    otp_app: :flotas,
    adapter: Ecto.Adapters.Postgres
end
