defmodule FlowExampleWeb.Showcase do
  @moduledoc """
  UI building blocks shared by the showcase pages: the canvas frame, the
  options sidebar, form controls styling and the event log.
  """
  use Phoenix.Component

  import FlowExampleWeb.CoreComponents, only: [icon: 1]

  @doc """
  Class for `<.input type="checkbox">` rendered as a switch.
  """
  def switch_class do
    "relative h-5 w-9 shrink-0 cursor-pointer appearance-none rounded-full bg-base-300 transition-colors duration-200 " <>
      "before:absolute before:top-0.5 before:left-0.5 before:size-4 before:rounded-full before:bg-white before:shadow-sm " <>
      "before:transition-transform before:duration-200 checked:bg-primary checked:before:translate-x-4 " <>
      "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary mr-2"
  end

  @doc """
  Class for `<.input type="select">`.
  """
  def select_class do
    "w-full rounded-lg border border-base-300 bg-base-100 px-2.5 py-1.5 text-sm shadow-xs transition-colors " <>
      "hover:border-base-content/30 focus:border-primary focus:outline-none"
  end

  @doc """
  Full-height layout with the flow canvas and an optional options sidebar.
  """
  slot :inner_block, required: true
  slot :sidebar

  def canvas_layout(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-col md:flex-row">
      <div class="relative min-h-[420px] min-w-0 flex-1">
        {render_slot(@inner_block)}
      </div>
      <aside
        :if={@sidebar != []}
        class="max-h-[45vh] w-full shrink-0 overflow-y-auto border-t border-base-300 bg-base-100 md:max-h-none md:w-80 md:border-t-0 md:border-l"
      >
        {render_slot(@sidebar)}
      </aside>
    </div>
    """
  end

  @doc """
  A titled group of options inside the sidebar.
  """
  attr :title, :string, required: true
  attr :tag, :string, default: nil
  slot :inner_block, required: true

  def option_group(assigns) do
    ~H"""
    <section class="border-b border-base-300 px-5 py-4 last:border-b-0">
      <h2 class="mb-3 flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wider text-base-content/50">
        {@title}
        <span
          :if={@tag}
          class="rounded bg-success/15 px-1.5 py-0.5 text-[10px] tracking-normal normal-case text-success"
        >
          {@tag}
        </span>
      </h2>
      <div class="space-y-1">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  @doc """
  A range slider (the core `<.input>` has no range type).
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :min, :any, required: true
  attr :max, :any, required: true
  attr :step, :any, default: 1

  def range(assigns) do
    ~H"""
    <label class="mb-2 block">
      <span class="mb-1 flex items-center justify-between text-sm">
        {@label}
        <span class="rounded bg-base-200 px-1.5 font-mono text-xs text-base-content/70">
          {@field.value}
        </span>
      </span>
      <input
        type="range"
        id={@field.id}
        name={@field.name}
        value={@field.value}
        min={@min}
        max={@max}
        step={@step}
        class="h-1.5 w-full cursor-pointer appearance-none rounded-full bg-base-300 accent-primary"
      />
    </label>
    """
  end

  @doc """
  Small hint text.
  """
  slot :inner_block, required: true

  def hint(assigns) do
    ~H"""
    <p class="text-xs leading-relaxed text-base-content/55">{render_slot(@inner_block)}</p>
    """
  end

  @doc """
  Keyboard key.
  """
  slot :inner_block, required: true

  def kbd(assigns) do
    ~H"""
    <kbd class="rounded border border-base-300 border-b-2 bg-base-100 px-1.5 py-px font-mono text-[11px] text-base-content/80">
      {render_slot(@inner_block)}
    </kbd>
    """
  end

  @doc """
  Header action button.
  """
  attr :icon, :string, default: nil
  attr :variant, :atom, default: :ghost, values: [:ghost, :primary]
  attr :rest, :global, include: ~w(disabled)
  slot :inner_block, required: true

  def action(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition-all duration-150 active:scale-95 disabled:pointer-events-none disabled:opacity-40",
        @variant == :primary && "bg-primary text-primary-content shadow-sm hover:brightness-110",
        @variant == :ghost &&
          "border border-base-300 bg-base-100 hover:border-base-content/20 hover:bg-base-200"
      ]}
      {@rest}
    >
      <.icon :if={@icon} name={@icon} class="size-4" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  The list of `lf:*` events received by the LiveView.
  """
  attr :id, :string, default: "event-log"
  attr :entries, :list, required: true

  def event_log(assigns) do
    ~H"""
    <div id={@id} class="space-y-1 font-mono text-[11px]">
      <p :if={@entries == []} class="text-base-content/40">Interact with the flow…</p>
      <div
        :for={entry <- @entries}
        id={"#{@id}-#{entry.id}"}
        class="rounded-md bg-base-200/70 px-2 py-1"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="font-semibold text-primary">{entry.event}</span>
          <span class="text-base-content/40">{Calendar.strftime(entry.at, "%H:%M:%S")}</span>
        </div>
        <p :if={entry.summary != ""} class="truncate text-base-content/60">{entry.summary}</p>
      </div>
    </div>
    """
  end
end
