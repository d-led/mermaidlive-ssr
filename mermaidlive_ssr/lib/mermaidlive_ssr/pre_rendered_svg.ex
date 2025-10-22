defmodule MermaidliveSsr.PreRenderedSvg do
  @moduledoc """
  Provides pre-rendered SVG templates for FSM states.

  This module contains pre-rendered SVG templates for different FSM states
  and provides functionality to customize them with specific values.
  """
  def render_state(graph_state \\ "waiting", counter \\ 0) do
    case graph_state do
      "working" when counter > 0 ->
        fetch_pre_rendered({"working", counter})

      "working" ->
        fetch_pre_rendered("working-generic")

      _ ->
        fetch_pre_rendered(graph_state)
    end
  end

  defmodule Embed do
    @moduledoc """
    Helper module for embedding SVG content into HTML.
    """
    def embed do
      Path.wildcard("priv/pre-rendering/output/*.svg")
      |> Enum.map(fn path ->
        {path |> Path.basename(".svg"), File.read!(path)}
      end)
      |> Enum.into(%{})
    end
  end

  @static_cache Embed.embed()

  def get_static_svg(name) do
    case @static_cache[name] do
      nil -> {:error, {:not_found, name}}
      svg -> {:ok, svg}
    end
  end

  defp fetch_pre_rendered({graph_state, extended_state}) do
    {:ok, svg} = get_static_svg("#{graph_state}-#{extended_state}")

    replaced_svg =
      svg
      |> String.replace(">XX<", ">#{extended_state}<")

    {:ok, replaced_svg}
  end

  defp fetch_pre_rendered(graph_state) do
    get_static_svg("#{graph_state}")
  end
end
