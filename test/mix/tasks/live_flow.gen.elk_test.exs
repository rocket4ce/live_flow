defmodule Mix.Tasks.LiveFlow.Gen.ElkTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.LiveFlow.Gen.Elk

  @app_js """
  import "phoenix_html"
  import {Socket} from "phoenix"
  import {LiveSocket} from "phoenix_live_view"
  import {LiveFlowHook} from "live_flow"

  const liveSocket = new LiveSocket("/live", Socket, {hooks: {LiveFlow: LiveFlowHook}})
  liveSocket.connect()
  """

  setup %{tmp_dir: tmp_dir} do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    assets = Path.join(tmp_dir, "assets")
    File.mkdir_p!(Path.join(assets, "js"))
    File.write!(Path.join(assets, "js/app.js"), @app_js)

    %{assets: assets}
  end

  @tag :tmp_dir
  test "copies elkjs and registers it after the live_flow import", %{assets: assets} do
    Elk.run(["--assets", assets])

    assert File.stat!(Path.join(assets, "vendor/elk.bundled.cjs")).size > 1_000_000

    app_js = File.read!(Path.join(assets, "js/app.js"))

    assert app_js =~
             ~s|import {LiveFlowHook} from "live_flow"\n\n| <>
               ~s|// ELK auto-layout engine for LiveFlow (mix live_flow.gen.elk)\n| <>
               ~s|import ELK from "../vendor/elk.bundled.cjs"\n| <>
               ~s|import {registerElk} from "live_flow"\n| <>
               ~s|registerElk(ELK)\n\nconst liveSocket|
  end

  @tag :tmp_dir
  test "running it again changes nothing", %{assets: assets} do
    Elk.run(["--assets", assets])
    app_js = File.read!(Path.join(assets, "js/app.js"))

    Elk.run(["--assets", assets])

    assert File.read!(Path.join(assets, "js/app.js")) == app_js
    assert_received {:mix_shell, :info, ["* skipping " <> _]}
  end

  @tag :tmp_dir
  test "--no-import only copies the file", %{assets: assets} do
    Elk.run(["--assets", assets, "--no-import"])

    assert File.exists?(Path.join(assets, "vendor/elk.bundled.cjs"))
    assert File.read!(Path.join(assets, "js/app.js")) == @app_js
  end

  @tag :tmp_dir
  test "prints the snippet when the entry point is missing", %{assets: assets} do
    Elk.run(["--assets", assets, "--entry", "js/missing.js"])

    assert_received {:mix_shell, :info, ["* missing " <> message]}
    assert message =~ ~s|import ELK from "../vendor/elk.bundled.cjs"|
  end
end
