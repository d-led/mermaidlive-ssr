defmodule MermaidLiveSsrWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :mermaidlive_ssr,
    pubsub_server: MermaidLiveSsr.PubSub

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_metas(_topic, %{joins: joins, leaves: leaves}, presences, state) do
    # Handle joins
    for {user_id, _presence} <- joins do
      MermaidLiveSsr.VisitorTracker.joined(user_id)
    end

    # Handle leaves
    for {user_id, _presence} <- leaves do
      MermaidLiveSsr.VisitorTracker.left(user_id)
    end

    # Calculate and broadcast presence updates
    active_count = map_size(presences)
    total_count = MermaidLiveSsr.VisitorTracker.get_total_count()

    # Broadcast to presence channel for LiveView updates
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "presence_updates",
      {:presence_update, %{
        active_count: active_count,
        total_count: total_count,
        cluster_count: active_count  # For now, same as active (single replica)
      }}
    )

    {:ok, state}
  end
end
