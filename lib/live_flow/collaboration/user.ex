defmodule LiveFlow.Collaboration.User do
  @moduledoc """
  Represents a user in a collaborative flow session.

  ## Fields

    * `:id` - Unique user identifier (required)
    * `:name` - Display name (auto-generated if not provided)
    * `:color` - Cursor/highlight color as hex string (auto-generated if not provided)

  ## Examples

      iex> user = LiveFlow.Collaboration.User.new("user_123")
      iex> user.id
      "user_123"

      iex> user = LiveFlow.Collaboration.User.new("user_123", name: "Alice", color: "#ef4444")
      iex> user.name
      "Alice"
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          color: String.t()
        }

  defstruct [:id, :name, :color]

  @colors ~w(#ef4444 #f97316 #f59e0b #22c55e #14b8a6 #3b82f6 #8b5cf6 #ec4899 #06b6d4 #84cc16)

  @doc """
  Creates a new user with the given ID.

  Options:
    * `:name` - Display name. Defaults to "User N" where N is derived from the ID.
    * `:color` - Hex color string. Defaults to a color deterministically chosen from the ID.
  """
  @spec new(String.t(), keyword()) :: t()
  def new(id, opts \\ []) do
    hash = :erlang.phash2(id)

    %__MODULE__{
      id: id,
      name: Keyword.get(opts, :name, "User #{rem(hash, 99) + 1}"),
      color: Keyword.get(opts, :color, Enum.at(@colors, rem(hash, length(@colors))))
    }
  end

  @doc """
  Returns the user data as a map suitable for Presence metadata.
  """
  @spec to_presence_meta(t()) :: map()
  def to_presence_meta(%__MODULE__{} = user) do
    %{
      name: user.name,
      color: user.color,
      joined_at: System.system_time(:second)
    }
  end
end
