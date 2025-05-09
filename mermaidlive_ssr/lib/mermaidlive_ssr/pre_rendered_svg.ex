defmodule MermaidliveSsr.PreRenderedSvg do
  def render_state(graph_state \\ "waiting") do
    fetch_pre_rendered(graph_state)
  end

  defmodule Embed do
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
      nil -> {:error, :not_found}
      svg -> {:ok, svg}
    end
  end

  defp fetch_pre_rendered({graph_state, extended_state}) do
    get_static_svg("#{graph_state}-#{extended_state}")
  end

  defp fetch_pre_rendered(graph_state) do
    get_static_svg("#{graph_state}")
  end
end
