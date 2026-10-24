defmodule FlowExampleWeb.ExamplesLive do
  @moduledoc """
  Gallery of every React Flow example ported to LiveFlow.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.Examples

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Examples")
     |> assign(:form, to_form(%{"query" => "", "pro" => "false"}, as: :filter))
     |> assign(:categories, Examples.by_category())
     |> assign(:count, length(Examples.all()))
     |> assign(:pro_count, Enum.count(Examples.all(), & &1.pro))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active={:examples}
      title="Examples"
      subtitle={"The #{@count} React Flow examples (#{@pro_count} Pro) rebuilt with LiveFlow and Phoenix LiveView."}
    >
      <div class="h-full overflow-y-auto">
        <div class="mx-auto max-w-6xl space-y-10 px-6 py-8">
          <.form
            for={@form}
            id="examples-filter"
            phx-change="filter"
            class="flex flex-wrap items-center gap-4"
          >
            <div class="relative w-full max-w-sm">
              <.icon
                name="hero-magnifying-glass"
                class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-base-content/40"
              />
              <input
                type="search"
                name={@form[:query].name}
                value={@form[:query].value}
                placeholder="Search examples…"
                phx-debounce="150"
                autocomplete="off"
                class="w-full rounded-lg border border-base-300 bg-base-100 py-2 pr-3 pl-9 text-sm shadow-xs transition-colors focus:border-primary focus:outline-none"
              />
            </div>
            <.input field={@form[:pro]} type="checkbox" label="Pro only" class={switch_class()} />
          </.form>

          <p
            :if={Enum.all?(@categories, fn {_, _, examples} -> examples == [] end)}
            class="text-sm text-base-content/50"
          >
            No example matches your search.
          </p>

          <section
            :for={{category, label, examples} <- @categories}
            :if={examples != []}
            id={"category-#{category}"}
          >
            <h2 class="mb-4 text-sm font-semibold uppercase tracking-wider text-base-content/50">
              {label} <span class="font-mono text-base-content/30">{length(examples)}</span>
            </h2>
            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <.link
                :for={example <- examples}
                id={"example-#{category}-#{example.slug}"}
                navigate={example.path}
                class="group flex flex-col rounded-xl border border-base-300 bg-base-100 p-4 transition-all duration-200 hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-lg hover:shadow-primary/5"
              >
                <div class="flex items-center gap-2">
                  <h3 class="font-medium">{example.title}</h3>
                  <span
                    :if={example.pro}
                    class="rounded bg-accent/15 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-accent"
                  >
                    PRO
                  </span>
                  <.icon
                    name="hero-arrow-right-mini"
                    class="ml-auto size-4 opacity-0 transition-all group-hover:translate-x-0.5 group-hover:opacity-60"
                  />
                </div>
                <p class="mt-1 text-sm leading-relaxed text-base-content/60">{example.description}</p>
              </.link>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("filter", %{"filter" => params}, socket) do
    query = params |> Map.get("query", "") |> String.trim() |> String.downcase()
    pro_only = params["pro"] == "true"

    categories =
      Enum.map(Examples.by_category(), fn {category, label, examples} ->
        {category, label,
         Enum.filter(examples, fn example ->
           (not pro_only or example.pro) and
             (query == "" or
                String.contains?(
                  String.downcase(example.title <> " " <> example.description),
                  query
                ))
         end)}
      end)

    {:noreply, assign(socket, categories: categories, form: to_form(params, as: :filter))}
  end
end
