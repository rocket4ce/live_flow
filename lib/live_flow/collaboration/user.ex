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

  # A color ends up inside a `background: …` declaration and an SVG `fill`, so
  # it must stay a single value: the characters below are the ones that would
  # end the declaration, close the rule, or start markup. Everything else is
  # allowed, so modern CSS colors (`oklch(…)`, `color-mix(…)`, `var(…)`) work.
  # `url(` is rejected too: it is a valid background value, but it would turn
  # a display color into an outbound request for everyone in the room.
  @color_forbidden [";", "{", "}", "<", ">", "\"", "'", "\\", "/*", "url(", "expression("]
  @color_max_length 64

  @doc """
  Creates a new user with the given ID.

  Options:
    * `:name` - Display name. Defaults to "User N" where N is derived from the ID.
    * `:color` - Hex color string. Defaults to a color deterministically chosen from the ID.

  The name is free text — LiveFlow always renders it as text, never as markup.
  The color is checked with `safe_color/2` and falls back to the deterministic
  palette color when it is not a plain CSS color.
  """
  @spec new(String.t(), keyword()) :: t()
  def new(id, opts \\ []) do
    hash = :erlang.phash2(id)
    default_color = Enum.at(@colors, rem(hash, length(@colors)))

    %__MODULE__{
      id: id,
      name: Keyword.get(opts, :name, "User #{rem(hash, 99) + 1}"),
      color: safe_color(Keyword.get(opts, :color), default_color)
    }
  end

  @doc """
  Returns `color` when it is usable as a CSS color, and `fallback` otherwise.

  Display colors can come from whoever is in the room, and they are rendered
  inside a `style` attribute, so a value that could end the declaration or
  start markup is replaced instead of reaching the page. Any other CSS color
  is passed through, including `var()`, `oklch()` and `color-mix()`.

  ## Examples

      iex> LiveFlow.Collaboration.User.safe_color("#ef4444")
      "#ef4444"

      iex> LiveFlow.Collaboration.User.safe_color("oklch(60% 0.25 292)")
      "oklch(60% 0.25 292)"

      iex> LiveFlow.Collaboration.User.safe_color("red; position: fixed; inset: 0")
      "#888888"
  """
  @spec safe_color(term(), String.t()) :: String.t()
  def safe_color(color, fallback \\ "#888888")

  def safe_color(color, fallback) when is_binary(color) do
    trimmed = String.trim(color)

    if trimmed != "" and String.length(trimmed) <= @color_max_length and
         not String.contains?(String.downcase(trimmed), @color_forbidden) do
      trimmed
    else
      fallback
    end
  end

  def safe_color(_color, fallback), do: fallback

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
