defmodule MermaidLiveSsr.VisitorTracker do
  @moduledoc """
  Tracks visitors using Phoenix Presence and publishes events.
  Similar to the Go implementation but using Elixir/Phoenix patterns.
  """

  use GenServer
  require Logger

  # Public API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def joined(visitor_id) do
    GenServer.call(__MODULE__, {:joined, visitor_id})
  end

  def left(visitor_id) do
    GenServer.call(__MODULE__, {:left, visitor_id})
  end

  def get_active_count do
    GenServer.call(__MODULE__, :get_active_count)
  end

  def get_total_count do
    GenServer.call(__MODULE__, :get_total_count)
  end

  # GenServer callbacks
  @impl true
  def init(_opts) do
    # Initialize ETS table for total visitor counter
    :ets.new(:visitor_counter, [:named_table, :public, :set])
    :ets.insert(:visitor_counter, {:total, 0})
    
    {:ok, %{active_count: 0, total_count: 0}}
  end

  @impl true
  def handle_call({:joined, visitor_id}, _from, state) do
    new_active = state.active_count + 1
    new_total = state.total_count + 1
    
    # Update ETS table
    :ets.insert(:visitor_counter, {:total, new_total})
    
    # Publish events
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:visitors_active, new_active}
    )
    
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:total_visitors, new_total}
    )
    
    Logger.info("Visitor joined: #{visitor_id}, active: #{new_active}, total: #{new_total}")
    
    {:reply, :ok, %{state | active_count: new_active, total_count: new_total}}
  end

  @impl true
  def handle_call({:left, visitor_id}, _from, state) do
    new_active = max(0, state.active_count - 1)
    
    # Publish events
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:visitors_active, new_active}
    )
    
    Logger.info("Visitor left: #{visitor_id}, active: #{new_active}")
    
    {:reply, :ok, %{state | active_count: new_active}}
  end

  @impl true
  def handle_call(:get_active_count, _from, state) do
    {:reply, state.active_count, state}
  end

  @impl true
  def handle_call(:get_total_count, _from, state) do
    {:reply, state.total_count, state}
  end
end
