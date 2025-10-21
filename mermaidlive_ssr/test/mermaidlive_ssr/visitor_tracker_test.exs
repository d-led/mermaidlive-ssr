defmodule MermaidLiveSsr.VisitorTrackerTest do
  use ExUnit.Case, async: true

  describe "VisitorTracker" do
    setup do
      # Start the application if not already started
      Application.ensure_all_started(:mermaidlive_ssr)

      # Start VisitorTracker if not already started
      case MermaidLiveSsr.VisitorTracker.start_link() do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      # Subscribe to events channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "events")

      %{}
    end

    test "tracks visitor joins and publishes events" do
      visitor_id = "test_visitor_#{System.unique_integer([:positive])}"

      # Get current counts
      current_active = MermaidLiveSsr.VisitorTracker.get_active_count()
      current_total = MermaidLiveSsr.VisitorTracker.get_total_count()

      # Join visitor
      MermaidLiveSsr.VisitorTracker.joined(visitor_id)

      # Should receive visitor events with incremented counts
      assert_receive {:visitors_active, new_active} when new_active > current_active
      assert_receive {:total_visitors, new_total} when new_total > current_total
    end

    test "tracks visitor leaves and publishes events" do
      visitor_id = "test_visitor_#{System.unique_integer([:positive])}"

      # Get initial active count
      initial_active = MermaidLiveSsr.VisitorTracker.get_active_count()

      # Join then leave visitor
      MermaidLiveSsr.VisitorTracker.joined(visitor_id)
      MermaidLiveSsr.VisitorTracker.left(visitor_id)

      # Should receive leave event (active count should be back to initial)
      assert_receive {:visitors_active, ^initial_active}
    end

    test "maintains correct counts" do
      visitor1 = "test_visitor_1_#{System.unique_integer([:positive])}"
      visitor2 = "test_visitor_2_#{System.unique_integer([:positive])}"

      # Get initial counts
      initial_active = MermaidLiveSsr.VisitorTracker.get_active_count()
      initial_total = MermaidLiveSsr.VisitorTracker.get_total_count()

      # Join two visitors
      MermaidLiveSsr.VisitorTracker.joined(visitor1)
      MermaidLiveSsr.VisitorTracker.joined(visitor2)

      # Check counts
      assert MermaidLiveSsr.VisitorTracker.get_active_count() == initial_active + 2
      assert MermaidLiveSsr.VisitorTracker.get_total_count() == initial_total + 2

      # Leave one visitor
      MermaidLiveSsr.VisitorTracker.left(visitor1)

      # Check counts
      assert MermaidLiveSsr.VisitorTracker.get_active_count() == initial_active + 1
      assert MermaidLiveSsr.VisitorTracker.get_total_count() == initial_total + 2  # Total should not decrease
    end
  end
end
