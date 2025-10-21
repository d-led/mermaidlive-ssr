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
  def handle_metas(_topic, %{joins: _joins, leaves: _leaves}, presences, state) do
    # Calculate and broadcast presence updates
    active_count = map_size(presences)

    # Broadcast to presence channel for LiveView updates
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "presence_updates",
      {:presence_update, %{
        active_count: active_count,
        total_count: active_count,  # For now, same as active
        cluster_count: active_count  # For now, same as active
      }}
    )

    {:ok, state}
  end
end
