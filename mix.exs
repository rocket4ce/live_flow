defmodule LiveFlow.MixProject do
  use Mix.Project

  @version "0.2.2"
  @source_url "https://github.com/rocket4ce/live_flow"

  def project do
    [
      app: :live_flow,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      name: "LiveFlow",
      homepage_url: @source_url,
      source_url: @source_url,
      description: """
      Interactive node-based flow diagrams for Phoenix LiveView.
      A library for building visual node editors, workflow builders,
      and interactive diagrams similar to React Flow, but for LiveView.
      """
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7 or ~> 1.8"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:jason, "~> 1.2"},
      {:esbuild, "~> 0.10", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["rocket4ce"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files:
        ~w(assets/js assets/css lib priv/static) ++
          ~w(CHANGELOG.md LICENSE.md mix.exs package.json README.md .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "LiveFlow",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/getting-started.md",
        "guides/custom-nodes.md",
        "guides/collaboration.md",
        "guides/themes.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "Core Data Structures": [
          LiveFlow.Node,
          LiveFlow.Edge,
          LiveFlow.Handle,
          LiveFlow.Viewport,
          LiveFlow.State
        ],
        Components: [
          LiveFlow.Components.Flow,
          LiveFlow.Components.NodeWrapper,
          LiveFlow.Components.Edge,
          LiveFlow.Components.Handle,
          LiveFlow.Components.Marker
        ],
        "Path Algorithms": [
          LiveFlow.Paths.Bezier,
          LiveFlow.Paths.Straight,
          LiveFlow.Paths.Step,
          LiveFlow.Paths.Smoothstep,
          LiveFlow.Paths.Path
        ],
        Features: [
          LiveFlow.History,
          LiveFlow.Clipboard,
          LiveFlow.Serializer,
          LiveFlow.Layout,
          LiveFlow.Validation,
          LiveFlow.Validation.Connection
        ],
        Collaboration: [
          LiveFlow.Collaboration,
          LiveFlow.Collaboration.User
        ],
        "Change Tracking": [
          LiveFlow.Changes.NodeChange,
          LiveFlow.Changes.EdgeChange
        ]
      ]
    ]
  end

  defp aliases do
    [
      "assets.build": ["cmd --cd assets node js/build.mjs"]
    ]
  end
end
