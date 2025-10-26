defmodule MermaidLiveSsr.VisitorCounter do
  @moduledoc """
  A visitor counter using G-Counter CRDT for distributed counting.

  This module provides a conflict-free replicated data type (CRDT) based
  visitor counter that can be safely used across multiple nodes in a cluster.
  The counter uses the node name as the peer identity and persists state
  using :ets tables.
  """

  use VirtualTimeGenServer
  require Logger

  @table_name :visitor_counter_state
  @persistence_file "visitor_counter_state.dat"

  # Public API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    # Extract init-specific opts (table_name, persistence_file)
    # vs start_link opts (name, virtual_clock, real_time, etc.)
    init_opts = Keyword.take(opts, [:table_name, :persistence_file])
    server_opts = Keyword.drop(opts, [:table_name, :persistence_file])
    VirtualTimeGenServer.start_link(__MODULE__, init_opts, [name: name] ++ server_opts)
  end

  @doc """
  Increment the visitor counter for the current node.
  """
  def increment do
    GenServer.call(__MODULE__, :increment)
  end

  @doc """
  Get the current total visitor count.
  """
  def get_count do
    GenServer.call(__MODULE__, :get_count)
  end

  @doc """
  Get the current counter state (for debugging/inspection).
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Merge counter state from another node.
  This is typically called when receiving state from other nodes in the cluster.
  """
  def merge_state(external_state) do
    GenServer.call(__MODULE__, {:merge_state, external_state})
  end

  @doc """
  Get the current node's contribution to the counter.
  """
  def get_node_count do
    GenServer.call(__MODULE__, :get_node_count)
  end

  @doc """
  Manually trigger persistence of the counter state.
  """
  def persist_state do
    GenServer.call(__MODULE__, :persist_state)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    # Get custom table name and persistence file from opts
    table_name = Keyword.get(opts, :table_name, @table_name)
    persistence_file = Keyword.get(opts, :persistence_file, @persistence_file)

    # Create or get the ETS table
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :public, :set])

      _table ->
        :ok
    end

    # Load persisted state if available
    state = load_persisted_state(persistence_file)

    # No periodic persistence - we rely on debounced persistence only

    Logger.info("VisitorCounter started with initial state: #{inspect(state)}")

    {:ok,
     %{
       state: state,
       table_name: table_name,
       persistence_file: persistence_file,
       debounce_timer: nil,
       has_changes: false
     }}
  end

  @impl true
  def handle_call(:increment, _from, %{state: state, table_name: table_name} = server_state) do
    node_name = get_node_identity()

    # Get current node count and increment it
    current_count = get_node_count_from_state(state, node_name)
    new_count = current_count + 1

    # Update the state with the new count
    new_state = put_node_count(state, node_name, new_count)

    # Store in ETS for immediate access
    :ets.insert(table_name, {:counter_state, new_state})

    # Get the total count
    total_count = get_total_count_from_state(new_state)

    Logger.debug(
      "Visitor counter incremented. Node: #{node_name}, Node Count: #{new_count}, Total: #{total_count}"
    )

    # Broadcast the updated count to all LiveViews
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "visitor_counter_updates",
      {:visitor_count_updated, total_count}
    )

    # Schedule debounced persistence - cancel any existing timer and start a new one
    new_server_state = schedule_debounced_persistence(server_state)

    {:reply, total_count, %{new_server_state | state: new_state, has_changes: true}}
  end

  @impl true
  def handle_call(:get_count, _from, %{state: state} = server_state) do
    count = get_total_count_from_state(state)
    {:reply, count, server_state}
  end

  @impl true
  def handle_call(:get_state, _from, %{state: state} = server_state) do
    {:reply, state, server_state}
  end

  @impl true
  def handle_call(
        {:merge_state, external_state},
        _from,
        %{state: state, table_name: table_name} = server_state
      ) do
    # Merge the external state with our current state
    merged_state = merge_states(state, external_state)

    # Store merged state in ETS
    :ets.insert(table_name, {:counter_state, merged_state})

    count = get_total_count_from_state(merged_state)
    Logger.info("Merged external counter state. New count: #{count}")

    {:reply, count, %{server_state | state: merged_state}}
  end

  @impl true
  def handle_call(:get_node_count, _from, %{state: state} = server_state) do
    node_name = get_node_identity()
    node_count = get_node_count_from_state(state, node_name)
    {:reply, node_count, server_state}
  end

  @impl true
  def handle_call(
        :persist_state,
        _from,
        %{state: state, persistence_file: persistence_file} = server_state
      ) do
    persist_state(state, persistence_file, :manual)
    {:reply, :ok, server_state}
  end

  @impl true
  def handle_info(
        :debounced_persist_state,
        %{state: state, persistence_file: persistence_file, has_changes: has_changes} =
          server_state
      ) do
    # Only persist if there are actual changes
    if has_changes do
      persist_state(state, persistence_file, :debounced)
      Logger.debug("Debounced persistence: state saved")
    else
      Logger.debug("Debounced persistence: no changes, skipping save")
    end

    {:noreply, %{server_state | debounce_timer: nil, has_changes: false}}
  end

  # Private functions

  defp get_node_identity do
    # Use node name as the peer identity
    node() |> Atom.to_string()
  end

  defp get_node_count_from_state(state, node_name) do
    case Map.get(state, node_name) do
      nil -> 0
      count when is_integer(count) -> count
      _ -> 0
    end
  end

  defp put_node_count(state, node_name, count) do
    Map.put(state, node_name, count)
  end

  defp get_total_count_from_state(state) do
    state
    |> Map.values()
    |> Enum.filter(&is_integer/1)
    |> Enum.sum()
  end

  defp merge_states(state1, state2) do
    # For a gcounter, we take the maximum value for each node
    all_nodes = MapSet.union(MapSet.new(Map.keys(state1)), MapSet.new(Map.keys(state2)))

    Enum.reduce(all_nodes, %{}, fn node_name, acc ->
      count1 = get_node_count_from_state(state1, node_name)
      count2 = get_node_count_from_state(state2, node_name)
      max_count = max(count1, count2)

      if max_count > 0 do
        Map.put(acc, node_name, max_count)
      else
        acc
      end
    end)
  end

  defp load_persisted_state(persistence_file) do
    case File.read(persistence_file) do
      {:ok, data} ->
        try do
          :erlang.binary_to_term(data)
        rescue
          _ ->
            Logger.warning("Failed to deserialize persisted state, starting fresh")
            %{}
        end

      {:error, :enoent} ->
        Logger.info("No persisted state found, starting with fresh counter")
        %{}

      {:error, reason} ->
        Logger.error("Failed to read persisted state: #{inspect(reason)}, starting fresh")
        %{}
    end
  end

  defp persist_state(state, persistence_file, reason) do
    data = :erlang.term_to_binary(state)
    File.write!(persistence_file, data)
    Logger.debug("Persisted visitor counter state (#{reason})")
  rescue
    error ->
      Logger.error("Failed to persist state: #{inspect(error)}")
  end

  defp schedule_debounced_persistence(%{debounce_timer: nil} = server_state) do
    # No existing timer, schedule debounced persistence
    timer = VirtualTimeGenServer.send_after(self(), :debounced_persist_state, 1000)
    %{server_state | debounce_timer: timer}
  end

  defp schedule_debounced_persistence(%{debounce_timer: timer} = server_state) do
    # Cancel existing timer and schedule a new one
    VirtualTimeGenServer.cancel_timer(timer)
    new_timer = VirtualTimeGenServer.send_after(self(), :debounced_persist_state, 1000)
    %{server_state | debounce_timer: new_timer}
  end

  # Child spec for supervision
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end
end
