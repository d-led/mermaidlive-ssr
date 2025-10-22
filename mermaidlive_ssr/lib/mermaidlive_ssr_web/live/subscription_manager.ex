defmodule MermaidLiveSsrWeb.Live.SubscriptionManager do
  @moduledoc """
  Handles PubSub subscriptions for LiveView components.

  This module extracts the logic for managing subscriptions to various
  channels and topics that the LiveView needs to listen to.
  """

  @doc """
  Subscribes to all necessary channels for the LiveView.

  This function subscribes to:
  - FSM-specific channel for state changes
  - Global events channel
  - Presence updates
  - Visitor counter updates

  ## Examples

      iex> SubscriptionManager.subscribe_to_channels("fsm_updates")
      :ok
  """
  def subscribe_to_channels(fsm_channel) do
    # Subscribe to the FSM-specific channel for state changes
    Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, fsm_channel)
    # Subscribe to global events channel
    Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "events")
    # Subscribe to presence updates
    Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "presence_updates")
    # Subscribe to visitor counter updates
    Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "visitor_counter_updates")
  end
end
