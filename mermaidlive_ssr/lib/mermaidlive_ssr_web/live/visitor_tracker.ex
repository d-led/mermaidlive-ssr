defmodule MermaidLiveSsrWeb.Live.VisitorTracker do
  @moduledoc """
  Handles visitor tracking and presence management for LiveView components.

  This module extracts the logic for tracking visitors, managing presence,
  and handling visitor counter updates.
  """

  @doc """
  Tracks a visitor using the VisitorCounter CRDT and Phoenix Presence.

  This function:
  1. Increments the visitor counter
  2. Creates a unique visitor ID
  3. Tracks the visitor in Phoenix Presence

  ## Examples

      iex> VisitorTracker.track_visitor(socket)
      :ok
  """
  def track_visitor(_socket) do
    # Increment the visitor counter
    MermaidLiveSsr.VisitorCounter.increment()

    visitor_id = "visitor_#{System.unique_integer([:positive])}"

    # Track in Presence - this will trigger presence_diff events
    MermaidLiveSsrWeb.Presence.track(
      self(),
      "visitors",
      visitor_id,
      %{
        online_at: System.system_time(:second),
        pid: self()
      }
    )
  end

  @doc """
  Loads initial visitor counts for the LiveView.

  Returns a tuple of {active_count, total_visitors} where:
  - active_count: number of currently active visitors
  - total_visitors: total number of visitors that have ever connected

  ## Examples

      iex> VisitorTracker.load_initial_counts(true)
      {3, 15}
  """
  def load_initial_counts(is_connected) do
    if is_connected do
      # Load initial values synchronously BEFORE tracking visitor
      presences = MermaidLiveSsrWeb.Presence.list("visitors")
      active_count = map_size(presences)
      total_visitors = MermaidLiveSsr.VisitorCounter.get_count()

      # Track this visitor (this will trigger PubSub broadcast)
      track_visitor(nil)

      {active_count, total_visitors}
    else
      # For non-connected state (SSR), read the persisted total via GenServer call
      total_visitors = MermaidLiveSsr.VisitorCounter.get_count()
      {0, total_visitors}
    end
  end
end
