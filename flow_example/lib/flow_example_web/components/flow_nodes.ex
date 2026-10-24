defmodule FlowExampleWeb.FlowNodes do
  @moduledoc """
  Custom node renderers used by the showcase (`node_types`).

  Text colors use the LiveFlow theme variables so nodes look right with every
  flow theme.
  """
  use FlowExampleWeb, :html

  @accents %{
    amber: "bg-amber-500/15 text-amber-600",
    sky: "bg-sky-500/15 text-sky-600",
    violet: "bg-violet-500/15 text-violet-600",
    emerald: "bg-emerald-500/15 text-emerald-600",
    rose: "bg-rose-500/15 text-rose-600",
    slate: "bg-slate-500/15 text-slate-500"
  }

  @doc """
  Node types map for `LiveFlow.Components.Flow`.
  """
  def types do
    %{card: &card/1, area: &area/1, person: &person/1}
  end

  @doc """
  A compact person/team node used by the layout examples (fixed 180x56 box).
  """
  attr :node, :map, required: true

  def person(assigns) do
    initials =
      assigns.node.data[:label]
      |> to_string()
      |> String.split()
      |> Enum.map_join(&String.first/1)
      |> String.slice(0, 2)

    assigns = assign(assigns, :initials, initials)

    ~H"""
    <div class="flex h-[36px] w-[150px] items-center gap-2.5">
      <span class="grid size-8 shrink-0 place-items-center rounded-full bg-primary/15 text-[11px] font-semibold text-primary">
        {@initials}
      </span>
      <div class="min-w-0">
        <p
          class="truncate text-[13px] leading-tight font-semibold"
          style="color: var(--lf-text-primary)"
        >
          {@node.data[:label]}
        </p>
        <p class="truncate text-[11px]" style="color: var(--lf-text-secondary)">
          {@node.data[:subtitle]}
        </p>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  def card(assigns) do
    assigns =
      assign(assigns, :accent, Map.get(@accents, assigns.node.data[:color], @accents.slate))

    ~H"""
    <div class="flex w-48 items-center gap-3">
      <span class={["grid size-9 shrink-0 place-items-center rounded-lg", @accent]}>
        <.icon name={@node.data[:icon] || "hero-cube"} class="size-5" />
      </span>
      <div class="min-w-0">
        <p
          class="truncate text-[13px] leading-tight font-semibold"
          style="color: var(--lf-text-primary)"
        >
          {@node.data[:title]}
        </p>
        <p class="truncate text-[11px]" style="color: var(--lf-text-secondary)">
          {@node.data[:subtitle]}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  A passive dashed area (used to visualize `node_extent`).
  """
  attr :node, :map, required: true

  def area(assigns) do
    ~H"""
    <div class="pointer-events-none flex h-full items-start justify-end p-2">
      <span class="rounded bg-primary/10 px-2 py-0.5 font-mono text-[11px] text-primary">
        {@node.data[:label]}
      </span>
    </div>
    """
  end
end
