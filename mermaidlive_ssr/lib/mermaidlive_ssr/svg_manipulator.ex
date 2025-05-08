defmodule MermaidLiveSsr.SvgManipulator do
  def fix_node_text_dimensions(svg) do
    svg
    |> Floki.parse_document!()
    |> Floki.traverse_and_update(fn
      {"g", g_attrs, children} = g_element ->
        with true <- is_state(g_attrs),
             {width, height} <- find_rect_dimensions(children) do
          {{old_width, old_height}, corrected_foreign_object} =
            g_element |> adjust_label_dimensions(width, height)

          IO.inspect({old_width, old_height}, label: "OLD")
          IO.inspect({width, height}, label: "NEW")
          IO.inspect({div(height - old_height, 2), div(width - old_width, 2)}, label: "THEORY")
          corrected_foreign_object |> adjust_text_position() |> IO.inspect(label: "CORRECTED")
        else
          _ ->
            g_element
        end

      other ->
        other
    end)
    |> Floki.attr(".label foreignobject", "width", fn
      "0" -> "0"
      string_value -> "#{String.to_integer(string_value) + 6}" |> IO.inspect(label: "WI")
    end)
    |> Floki.attr(".label foreignobject", "height", fn
      "0" -> "0"
      string_value -> "#{String.to_integer(string_value) + 6}" |> IO.inspect(label: "HE")
    end)
    |> Floki.attr(".edgeLabel .label foreignobject", "transform", fn
      _ -> "translate(0,-4)"
    end)
    |> Floki.raw_html()
  end

  defp is_state(g_attrs) do
    Enum.find(g_attrs, nil, fn el -> el == {"class", "node statediagram-state"} end) != nil
  end

  defp find_rect_dimensions(children) do
    rect = Floki.find(children, "rect") |> List.first()

    case rect do
      nil ->
        :not_found

      {"rect", _attrs, _children} ->
        with {:ok, width} <- find_number(rect, "width"),
             {:ok, height} <- find_number(rect, "height") do
          {width, height}
        else
          _ ->
            :not_found
        end
    end
  end

  defp find_number(el, key) do
    with [string_value] <- Floki.attribute(el, key) do
      {:ok, string_value |> String.to_integer()}
    else
      _ -> :not_found
    end
  end

  defp adjust_label_dimensions(el, width, height) do
    old_width =
      with [ow] <- Floki.attribute(el, "foreignobject", "width") do
        ow |> String.to_integer()
      else
        _ -> width
      end

    old_height =
      with [oh] <- Floki.attribute(el, "foreignobject", "height") do
        oh |> String.to_integer()
      else
        _ -> height
      end

    {{old_width, old_height},
     el
     |> Floki.attr("foreignobject", "width", fn _ -> "#{width}" end)
     |> Floki.attr("foreignobject", "height", fn _ -> "#{height}" end)}
  end

  defp adjust_text_position(el) do
    el
    |> Floki.attr("g", "transform", fn value ->
      Regex.replace(~r/translate\((-?\d+),\s*(-?\d+)/, value, fn _, x, y ->
        "translate(#{String.to_integer(x) - 2}, #{String.to_integer(y) - 2}"
      end)
    end)
  end
end
