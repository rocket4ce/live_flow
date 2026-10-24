defmodule FlowExampleWeb.ColocatedCSS do
  @moduledoc """
  Global colocated CSS: `<style :type={FlowExampleWeb.ColocatedCSS}>` at the
  very beginning of a template is extracted at compile time into the bundle
  (imported by `assets/css/app.css`). Used by examples for their own styles.
  """
  use Phoenix.LiveView.ColocatedCSS

  @impl true
  def transform("style", _attrs, css, _meta), do: {:ok, css, []}
end
