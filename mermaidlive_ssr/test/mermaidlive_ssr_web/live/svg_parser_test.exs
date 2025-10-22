defmodule MermaidLiveSsrWeb.Live.SvgParserTest do
  use ExUnit.Case, async: true

  alias MermaidLiveSsrWeb.Live.SvgParser

  describe "extract_state_from_svg/1" do
    test "extracts waiting state" do
      svg = ~s(<g class="state-waiting-4" class="node inProgress">Waiting</g>)
      assert SvgParser.extract_state_from_svg(svg) == "waiting"
    end

    test "extracts working state" do
      svg = ~s(<g class="state-working-5" class="node inProgress">Working</g>)
      assert SvgParser.extract_state_from_svg(svg) == "working"
    end

    test "extracts aborting state" do
      svg = ~s(<g class="state-aborting-4" class="node inProgress">Aborting</g>)
      assert SvgParser.extract_state_from_svg(svg) == "aborting"
    end

    test "returns waiting state as default when no state class found" do
      svg = ~s(<g class="node">Some other content</g>)
      assert SvgParser.extract_state_from_svg(svg) == "waiting"
    end

    test "handles empty SVG" do
      assert SvgParser.extract_state_from_svg("") == "waiting"
    end
  end

  describe "extract_counter_from_svg/1" do
    test "extracts counter from note content" do
      svg = ~s(<g class="node statediagram-state"><p>42</p></g>)
      assert SvgParser.extract_counter_from_svg(svg) == 42
    end

    test "extracts counter from different position in SVG" do
      svg = ~s(<svg><g><p>15</p></g></svg>)
      assert SvgParser.extract_counter_from_svg(svg) == 15
    end

    test "returns 0 when no counter found" do
      svg = ~s(<g class="node">No counter here</g>)
      assert SvgParser.extract_counter_from_svg(svg) == 0
    end

    test "handles empty SVG" do
      assert SvgParser.extract_counter_from_svg("") == 0
    end

    test "handles malformed counter text" do
      svg = ~s(<p>not a number</p>)
      assert SvgParser.extract_counter_from_svg(svg) == 0
    end

    test "handles multiple numbers, takes first match" do
      svg = ~s(<p>10</p><p>20</p>)
      assert SvgParser.extract_counter_from_svg(svg) == 10
    end
  end
end
