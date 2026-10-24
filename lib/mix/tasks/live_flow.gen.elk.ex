defmodule Mix.Tasks.LiveFlow.Gen.Elk do
  @shortdoc "Adds the ELK auto-layout engine to your assets"

  @moduledoc """
  Adds [ELK](https://eclipse.dev/elk/) (elkjs) to your app's JavaScript, for the
  client-side auto layout (`LiveFlow.Layout.prepare_layout_data/2` pushed as
  `lf:layout_data`, or `JS.dispatch("lf:auto-layout")`).

  ELK is optional because it adds about 1.6 MB to the bundle. The server-side
  layouts (`LiveFlow.Layout.tree/2`, `force/2`) and the JS tree layout
  (`prepare_tree_layout_data/2`) don't need it.

      $ mix live_flow.gen.elk

  The task:

    1. copies elkjs to `assets/vendor/elk.bundled.cjs`
    2. registers it in `assets/js/app.js`:

           import ELK from "../vendor/elk.bundled.cjs"
           import {registerElk} from "live_flow"
           registerElk(ELK)

  Running it again is safe: an existing vendor file is kept (unless
  `--force`) and `app.js` is changed only once.

  ## Options

    * `--assets` - the assets directory (default: `assets`)
    * `--entry` - the JS entry point, relative to the assets directory
      (default: `js/app.js`)
    * `--force` - overwrite `vendor/elk.bundled.cjs` if it exists
    * `--no-import` - only copy the file, leave the entry point untouched

  To use the npm package instead, run `npm install elkjs --prefix assets` and
  register `import ELK from "elkjs/lib/elk.bundled.js"`.
  """
  use Mix.Task

  @switches [assets: :string, entry: :string, force: :boolean, import: :boolean]

  @impl true
  def run(args) do
    {opts, _argv} = OptionParser.parse!(args, strict: @switches)

    assets = Keyword.get(opts, :assets, "assets")
    entry = Path.join(assets, Keyword.get(opts, :entry, "js/app.js"))
    vendor = Path.join([assets, "vendor", "elk.bundled.cjs"])

    copy_elk(vendor, Keyword.get(opts, :force, false))

    if Keyword.get(opts, :import, true) do
      register(entry, vendor)
    end
  end

  defp copy_elk(vendor, force?) do
    if File.exists?(vendor) and not force? do
      Mix.shell().info([:yellow, "* skipping ", :reset, vendor, " (exists, use --force)"])
    else
      File.mkdir_p!(Path.dirname(vendor))
      File.cp!(source(), vendor)
      Mix.shell().info([:green, "* creating ", :reset, vendor])
    end
  end

  defp source do
    Application.app_dir(:live_flow, "priv/templates/live_flow.gen.elk/elk.bundled.cjs")
  end

  defp register(entry, vendor) do
    snippet = snippet(relative_import(Path.dirname(entry), vendor))

    cond do
      not File.exists?(entry) ->
        Mix.shell().info([
          :yellow,
          "* missing ",
          :reset,
          entry,
          ". Register ELK in your JS entry point:\n\n",
          snippet
        ])

      File.read!(entry) =~ "registerElk" ->
        Mix.shell().info([:yellow, "* skipping ", :reset, entry, " (already registers ELK)"])

      true ->
        File.write!(entry, inject(File.read!(entry), snippet))
        Mix.shell().info([:green, "* updating ", :reset, entry])
    end
  end

  defp snippet(import_path) do
    """
    // ELK auto-layout engine for LiveFlow (mix live_flow.gen.elk)
    import ELK from "#{import_path}"
    import {registerElk} from "live_flow"
    registerElk(ELK)
    """
  end

  # After the line importing "live_flow", or the last import, or at the top
  defp inject(content, snippet) do
    lines = String.split(content, "\n")

    index =
      find_last(lines, &(&1 =~ ~r/from\s+["']live_flow["']/)) ||
        find_last(lines, &(&1 =~ ~r/^(import\s|\}\s*from\s).*["'];?\s*$/))

    case index do
      nil ->
        snippet <> "\n" <> content

      index ->
        {before, rest} = Enum.split(lines, index + 1)
        Enum.join(before ++ ["" | String.split(snippet, "\n", trim: true)] ++ rest, "\n")
    end
  end

  defp find_last(lines, fun) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} -> fun.(line) end)
    |> List.last()
    |> case do
      {_line, index} -> index
      nil -> nil
    end
  end

  # Path from the entry point's directory to the vendor file, e.g. "../vendor/elk.bundled.cjs"
  defp relative_import(from_dir, target) do
    {from, to} = drop_common(Path.split(Path.expand(from_dir)), Path.split(Path.expand(target)))
    path = Path.join(List.duplicate("..", length(from)) ++ to)

    if String.starts_with?(path, "../"), do: path, else: "./" <> path
  end

  defp drop_common([same | from], [same | to]), do: drop_common(from, to)
  defp drop_common(from, to), do: {from, to}
end
