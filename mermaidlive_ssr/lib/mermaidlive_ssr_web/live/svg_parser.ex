defmodule MermaidLiveSsrWeb.Live.SvgParser do
  @moduledoc """
  Handles SVG parsing and state extraction for LiveView components.

  This module extracts the logic for parsing SVG content to determine
  the current state and counter values.
  """

  @doc """
  Extracts state from SVG by looking for the inProgress class.

  ## Examples

      iex> SvgParser.extract_state_from_svg(~s(<g class="node inProgress state-waiting-4">))
      "waiting"

      iex> SvgParser.extract_state_from_svg(~s(<g class="node inProgress state-working-5">))
      "working"

      iex> SvgParser.extract_state_from_svg(~s(<g class="node inProgress state-aborting-4">))
      "aborting"
  """
  def extract_state_from_svg(svg) do
    cond do
      String.contains?(svg, "state-waiting-4\" class=\"node inProgress") -> "waiting"
      String.contains?(svg, "state-working-5\" class=\"node inProgress") -> "working"
      String.contains?(svg, "state-aborting-4\" class=\"node inProgress") -> "aborting"
      true -> "waiting"
    end
  end

  @doc """
  Extracts counter from SVG by looking for the note content.

  ## Examples

      iex> SvgParser.extract_counter_from_svg(~s(<p>42</p>))
      42

      iex> SvgParser.extract_counter_from_svg(~s(<div>No counter here</div>))
      0
  """
  def extract_counter_from_svg(svg) do
    case Regex.run(~r/<p>(\d+)<\/p>/, svg) do
      [_, counter_str] -> String.to_integer(counter_str)
      _ -> 0
    end
  end
end
