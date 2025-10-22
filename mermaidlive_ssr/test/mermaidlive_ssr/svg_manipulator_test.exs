defmodule MermaidLiveSsr.SvgManipulatorTest do
  use ExUnit.Case, async: true

  alias MermaidLiveSsr.SvgManipulator

  describe "fix_node_text_dimensions/1" do
    test "returns original SVG when no state nodes found" do
      svg = ~s(<svg><g class="other">Content</g></svg>)
      result = SvgManipulator.fix_node_text_dimensions(svg)
      assert result == svg
    end

    test "handles empty SVG" do
      result = SvgManipulator.fix_node_text_dimensions("")
      assert is_binary(result)
    end

    test "handles malformed SVG gracefully" do
      svg = "<invalid>svg</invalid>"
      # Should not crash, may return original or processed version
      assert is_binary(SvgManipulator.fix_node_text_dimensions(svg))
    end

    test "processes simple SVG without errors" do
      svg = ~s(<svg><g class="other">Content</g></svg>)
      # Should not crash
      assert is_binary(SvgManipulator.fix_node_text_dimensions(svg))
    end
  end
end
