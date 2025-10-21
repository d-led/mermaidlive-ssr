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
    # Initialize ETS table for total visitor counter if it doesn't exist
    case :ets.whereis(:visitor_counter) do
      :undefined ->
        :ets.new(:visitor_counter, [:named_table, :public, :set])
        :ets.insert(:visitor_counter, {:total, 0})
      _ -> :ok
    end

    {:ok, %{total_count: :ets.lookup_element(:visitor_counter, :total, 2)}}
  end

  @impl true
  def handle_metas(_topic, %{joins: joins, leaves: _leaves}, presences, state) do
    # Calculate and broadcast presence updates
    active_count = map_size(presences)

    # Update total count for new joins
    new_total = if map_size(joins) > 0 do
      current_total = :ets.lookup_element(:visitor_counter, :total, 2)
      new_total = current_total + map_size(joins)
      :ets.insert(:visitor_counter, {:total, new_total})
      new_total
    else
      :ets.lookup_element(:visitor_counter, :total, 2)
    end

    # Broadcast to presence channel for LiveView updates
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "presence_updates",
      {:presence_update, %{
        active_count: active_count,
        total_count: new_total,
        cluster_count: active_count  # For now, same as active
      }}
    )

    {:ok, state}
  end
end
