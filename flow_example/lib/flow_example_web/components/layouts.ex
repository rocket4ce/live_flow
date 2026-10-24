defmodule FlowExampleWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FlowExampleWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @nav [
    {"Start",
     [
       {:home, "Overview", "/", "hero-squares-2x2"},
       {:playground, "Playground", "/playground", "hero-sparkles"},
       {:examples, "All examples", "/examples", "hero-rectangle-group"}
     ]},
    {"LiveFlow",
     [
       {:interaction, "Interaction options", "/interaction", "hero-cursor-arrow-rays"},
       {:edges, "Edge paths", "/edges", "hero-arrows-right-left"},
       {:resizing, "Resizing", "/resizing", "hero-arrows-pointing-out"},
       {:custom_nodes, "Custom nodes", "/custom-nodes", "hero-cube"},
       {:large, "Large flows", "/large", "hero-rectangle-stack"}
     ]}
  ]

  @doc """
  Renders the showcase shell: navigation sidebar plus a page header.

  ## Examples

      <Layouts.app flash={@flash} active={:edges} title="Edges">
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :active, :atom, default: nil, doc: "the active navigation entry"
  attr :title, :string, default: nil
  attr :subtitle, :string, default: nil
  attr :badge, :string, default: nil

  slot :inner_block, required: true
  slot :actions, doc: "buttons rendered in the page header"

  def app(assigns) do
    assigns = assign(assigns, :nav, @nav)

    ~H"""
    <div class="flex h-dvh overflow-hidden bg-base-200 text-base-content">
      <aside class="hidden w-60 shrink-0 flex-col border-r border-base-300 bg-base-100 lg:flex">
        <.link navigate={~p"/"} class="group flex items-center gap-2.5 px-5 pt-5 pb-6">
          <.logo />
          <span class="text-[15px] font-semibold tracking-tight">LiveFlow</span>
          <span class="ml-auto rounded-full bg-primary/10 px-2 py-0.5 font-mono text-[10px] font-medium text-primary">
            v{live_flow_version()}
          </span>
        </.link>

        <nav class="flex-1 space-y-6 overflow-y-auto px-3 pb-6" aria-label="Examples">
          <div :for={{section, items} <- @nav}>
            <p class="px-2 pb-2 text-[11px] font-semibold uppercase tracking-wider text-base-content/40">
              {section}
            </p>
            <.link
              :for={{key, label, path, icon} <- items}
              navigate={path}
              class={[
                "group flex items-center gap-2.5 rounded-lg px-2 py-1.5 text-sm transition-colors duration-150",
                if(@active == key,
                  do: "bg-primary/10 font-medium text-primary",
                  else: "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                )
              ]}
            >
              <.icon name={icon} class="size-4 opacity-80 transition-transform group-hover:scale-110" />
              {label}
            </.link>
          </div>

          <div>
            <p class="px-2 pb-2 text-[11px] font-semibold uppercase tracking-wider text-base-content/40">
              React Flow examples
            </p>
            <details
              :for={{category, label, examples} <- FlowExampleWeb.Examples.by_category()}
              id={"nav-#{category}"}
              class="group/cat"
              open={Enum.any?(examples, &(&1.id == @active))}
            >
              <summary class="flex cursor-pointer list-none items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-base-content/70 transition-colors hover:bg-base-200 hover:text-base-content">
                <.icon
                  name="hero-chevron-right-mini"
                  class="size-4 opacity-60 transition-transform group-open/cat:rotate-90"
                />
                {label}
                <span class="ml-auto font-mono text-[10px] text-base-content/40">{length(examples)}</span>
              </summary>
              <div class="mt-0.5 mb-1 ml-4 border-l border-base-300 pl-2">
                <.link
                  :for={example <- examples}
                  navigate={example.path}
                  class={[
                    "flex items-center gap-1.5 rounded-md px-2 py-1 text-[13px] transition-colors duration-150",
                    if(@active == example.id,
                      do: "bg-primary/10 font-medium text-primary",
                      else: "text-base-content/60 hover:bg-base-200 hover:text-base-content"
                    )
                  ]}
                >
                  <span class="truncate">{example.title}</span>
                  <span
                    :if={example.pro}
                    class="ml-auto rounded bg-accent/15 px-1 font-mono text-[9px] font-semibold text-accent"
                  >
                    PRO
                  </span>
                </.link>
              </div>
            </details>
          </div>
        </nav>

        <div class="space-y-3 border-t border-base-300 p-4">
          <.theme_toggle />
          <a
            href="https://github.com/rocket4ce/live_flow"
            class="flex items-center gap-2 text-xs text-base-content/50 transition-colors hover:text-base-content"
          >
            <.icon name="hero-code-bracket" class="size-4" /> rocket4ce/live_flow
          </a>
        </div>
      </aside>

      <main class="flex min-w-0 flex-1 flex-col">
        <%!-- Compact navigation for small screens --%>
        <nav class="flex gap-1 overflow-x-auto border-b border-base-300 bg-base-100 px-3 py-2 lg:hidden">
          <.link
            :for={{key, label, path, _icon} <- Enum.flat_map(@nav, &elem(&1, 1))}
            navigate={path}
            class={[
              "whitespace-nowrap rounded-md px-2.5 py-1 text-xs",
              if(@active == key,
                do: "bg-primary/10 font-medium text-primary",
                else: "text-base-content/70"
              )
            ]}
          >
            {label}
          </.link>
        </nav>

        <header
          :if={@title}
          class="flex flex-wrap items-center justify-between gap-4 border-b border-base-300 bg-base-100 px-6 py-4"
        >
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h1 class="text-lg font-semibold tracking-tight">{@title}</h1>
              <span
                :if={@badge}
                class={[
                  "rounded-full px-2 py-0.5 text-[11px] font-medium",
                  if(@badge == "Pro",
                    do: "bg-accent/15 text-accent",
                    else: "bg-success/15 text-success"
                  )
                ]}
              >
                {@badge}
              </span>
            </div>
            <p :if={@subtitle} class="mt-0.5 max-w-3xl text-sm text-base-content/60">{@subtitle}</p>
          </div>
          <div :if={@actions != []} class="flex flex-wrap items-center gap-2">
            {render_slot(@actions)}
          </div>
        </header>

        <div class="relative min-h-0 flex-1">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Page shell of a React Flow example: header with links to the original
  example and to the source, the canvas and an optional sidebar.

  ## Examples

      <Layouts.example flash={@flash} example={@example}>
        <.live_component module={LiveFlow.Components.Flow} id="flow" flow={@flow} />
        <:sidebar>...</:sidebar>
      </Layouts.example>
  """
  attr :flash, :map, required: true
  attr :example, :map, required: true
  slot :inner_block, required: true
  slot :sidebar
  slot :actions

  def example(assigns) do
    ~H"""
    <.app
      flash={@flash}
      active={@example.id}
      title={@example.title}
      subtitle={@example.description}
      badge={@example.pro && "Pro"}
    >
      <:actions>
        {render_slot(@actions)}
        <a
          href={@example.reactflow_url}
          target="_blank"
          rel="noopener"
          class="inline-flex items-center gap-1 rounded-lg px-2 py-1.5 text-xs text-base-content/50 transition-colors hover:text-base-content"
          title="Original React Flow example"
        >
          React Flow <.icon name="hero-arrow-top-right-on-square-mini" class="size-3.5" />
        </a>
        <a
          :if={FlowExampleWeb.Examples.source_url(@example)}
          href={FlowExampleWeb.Examples.source_url(@example)}
          target="_blank"
          rel="noopener"
          class="inline-flex items-center gap-1 rounded-lg px-2 py-1.5 text-xs text-base-content/50 transition-colors hover:text-base-content"
          title="LiveView source"
        >
          <.icon name="hero-code-bracket-mini" class="size-3.5" /> Source
        </a>
      </:actions>

      <.canvas_layout>
        {render_slot(@inner_block)}
        <:sidebar :if={@sidebar != []}>{render_slot(@sidebar)}</:sidebar>
      </.canvas_layout>
    </.app>
    """
  end

  defp logo(assigns) do
    ~H"""
    <span class="grid size-7 place-items-center rounded-lg bg-gradient-to-br from-primary to-accent text-primary-content shadow-sm transition-transform duration-200 group-hover:rotate-6">
      <svg viewBox="0 0 24 24" class="size-4" fill="none" stroke="currentColor" stroke-width="2.2">
        <circle cx="5" cy="6" r="2.2" /><circle cx="19" cy="6" r="2.2" /><circle
          cx="12"
          cy="18"
          r="2.2"
        />
        <path d="M7 6h10M6.2 8l4.6 8M17.8 8l-4.6 8" stroke-linecap="round" />
      </svg>
    </span>
    """
  end

  defp live_flow_version do
    Application.spec(:live_flow, :vsn) |> to_string()
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
