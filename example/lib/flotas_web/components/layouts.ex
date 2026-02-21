defmodule FlotasWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FlotasWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
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
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
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
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
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
  Documentation layout with persistent left sidebar and right content area.
  """
  attr :flash, :map, required: true
  attr :current_page, :string, required: true
  slot :inner_block, required: true

  def docs(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open min-h-screen">
      <input id="docs-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content flex flex-col">
        <%!-- Mobile top bar --%>
        <div class="navbar bg-base-100 border-b border-base-300 lg:hidden px-4 sticky top-0 z-30">
          <label for="docs-drawer" class="btn btn-ghost btn-square">
            <.icon name="hero-bars-3" class="size-5" />
          </label>
          <span class="ml-2 font-semibold text-sm">LiveFlow Docs</span>
          <div class="flex-1" />
          <.theme_toggle />
        </div>

        <%!-- Page content --%>
        <main class="flex-1 p-6 lg:p-10 lg:pl-12">
          <div class="max-w-4xl">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>

      <%!-- Sidebar --%>
      <div class="drawer-side z-40">
        <label for="docs-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <aside class="w-72 min-h-full bg-base-200 border-r border-base-300 flex flex-col">
          <div class="p-4 border-b border-base-300 flex items-center justify-between">
            <a href="/" class="flex items-center gap-2 hover:opacity-80 transition-opacity">
              <img src={~p"/images/logo.svg"} width="28" />
              <span class="font-bold text-base-content">LiveFlow</span>
              <span class="badge badge-ghost badge-sm">v0.2.3</span>
            </a>
            <div class="hidden lg:block">
              <.theme_toggle />
            </div>
          </div>

          <.docs_sidebar current_page={@current_page} />
        </aside>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :current_page, :string, required: true

  defp docs_sidebar(assigns) do
    ~H"""
    <nav class="flex-1 overflow-y-auto py-4 px-3">
      <ul class="menu menu-sm gap-0.5">
        <li class="menu-title text-xs uppercase tracking-wider opacity-50 mb-1">Getting Started</li>
        <.sidebar_link page="quick-start" label="Quick Start" icon="hero-rocket-launch" current={@current_page} />

        <li class="menu-title text-xs uppercase tracking-wider opacity-50 mt-4 mb-1">Fundamentals</li>
        <.sidebar_link page="core-concepts" label="Core Concepts" icon="hero-cube-transparent" current={@current_page} />
        <.sidebar_link page="nodes" label="Nodes" icon="hero-square-3-stack-3d" current={@current_page} />
        <.sidebar_link page="edges" label="Edges & Handles" icon="hero-arrows-right-left" current={@current_page} />
        <.sidebar_link page="viewport" label="Viewport & Controls" icon="hero-viewfinder-circle" current={@current_page} />

        <li class="menu-title text-xs uppercase tracking-wider opacity-50 mt-4 mb-1">Deep Dive</li>
        <.sidebar_link page="state" label="State Management" icon="hero-circle-stack" current={@current_page} />
        <.sidebar_link page="advanced" label="Advanced Features" icon="hero-cog-6-tooth" current={@current_page} />

        <li class="menu-title text-xs uppercase tracking-wider opacity-50 mt-4 mb-1">Reference</li>
        <.sidebar_link page="reference" label="API Reference" icon="hero-book-open" current={@current_page} />

        <li class="divider my-3"></li>
        <li class="menu-title text-xs uppercase tracking-wider opacity-50 mb-1">Demos</li>
        <li><a href="/flow-demo" class="gap-2"><.icon name="hero-play" class="size-3.5" /> Flow Demo</a></li>
        <li><a href="/flow-forms" class="gap-2"><.icon name="hero-play" class="size-3.5" /> Flow Forms</a></li>
        <li><a href="/flow-realtime" class="gap-2"><.icon name="hero-play" class="size-3.5" /> Realtime</a></li>
        <li><a href="/flow-pipeline" class="gap-2"><.icon name="hero-play" class="size-3.5" /> Pipeline</a></li>
        <li><a href="/flow-custom-nodes" class="gap-2"><.icon name="hero-play" class="size-3.5" /> Custom Nodes</a></li>
        <li><a href="/flow-dynamic-layout" class="gap-2"><.icon name="hero-play" class="size-3.5" /> Dynamic Layout</a></li>
        <li><a href="/flow-shapes" class="gap-2"><.icon name="hero-play" class="size-3.5" /> Shapes</a></li>
      </ul>
    </nav>
    """
  end

  attr :page, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :current, :string, required: true

  defp sidebar_link(assigns) do
    ~H"""
    <li>
      <a
        href={~p"/docs/#{@page}"}
        class={["gap-2", @page == @current && "active font-semibold"]}
      >
        <.icon name={@icon} class="size-3.5" />
        {@label}
      </a>
    </li>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

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
