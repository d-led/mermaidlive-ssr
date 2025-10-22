defmodule MermaidLiveSsr.SvgManipulator do
  @moduledoc """
  Utilities for manipulating SVG content.

  This module provides functions for parsing and modifying SVG content,
  including extracting state information and adjusting label dimensions.
  """
  # not needed for now as a newer version of mermaid-cli is used
  def fix_node_text_dimensions(svg) do
    svg
    |> Floki.parse_document!()
    |> Floki.traverse_and_update(fn
      {"g", g_attrs, children} = g_element ->
        with true <- state?(g_attrs),
             {width, height} <- find_rect_dimensions(children) do
          {{_old_width, _old_height}, corrected_foreign_object} =
            g_element |> adjust_label_dimensions(width, height)

          corrected_foreign_object |> adjust_text_position()
        else
          _ ->
            g_element
        end

      other ->
        other
    end)
    |> Floki.attr(".label foreignobject", "width", fn
      "0" -> "0"
      string_value -> "#{to_int(string_value) + 6}"
    end)
    |> Floki.attr(".label foreignobject", "height", fn
      "0" -> "0"
      string_value -> "#{to_int(string_value) + 6}"
    end)
    |> Floki.attr(".edgeLabel .label foreignobject", "transform", fn
      _ -> "translate(0,-4)"
    end)
    |> Floki.raw_html()
  end

  defp state?(g_attrs) do
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
    case Floki.attribute(el, key) do
      [string_value] -> {:ok, string_value |> to_int()}
      _ -> :not_found
    end
  end

  defp adjust_label_dimensions(el, width, height) do
    old_width =
      case Floki.attribute(el, "foreignobject", "width") do
        [ow] -> ow |> to_int()
        _ -> width
      end

    old_height =
      case Floki.attribute(el, "foreignobject", "height") do
        [oh] -> oh |> to_int()
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
        "translate(#{to_int(x) - 2}, #{to_int(y) - 2}"
      end)
    end)
  end

  defp to_int(num_string) do
    {num, ""} = Float.parse(num_string)
    trunc(num)
  end
end
