defmodule MermaidLiveSsr.CountdownFSM do
  @behaviour :gen_statem

  @fsm_updates_channel "fsm_updates"
  @default_tick_interval 100

  # Public API
  def start_link(opts \\ []) do
    :gen_statem.start_link({:local, __MODULE__}, __MODULE__, opts, [])
  end

  def start_link(opts, name) when is_atom(name) do
    :gen_statem.start_link({:local, name}, __MODULE__, opts, [])
  end

  # Send command to FSM (supports both named and PID references)
  def send_command(fsm \\ __MODULE__, command) do
    :gen_statem.cast(fsm, command)
  end

  # Get current state of FSM (supports both named and PID references)
  def get_state(fsm \\ __MODULE__) do
    :gen_statem.call(fsm, :get_state)
  end

  # Helper function to get the channel for a specific FSM PID
  def get_channel_for_pid(pid) when is_pid(pid) do
    "fsm_#{:erlang.pid_to_list(pid) |> List.to_string() |> String.replace(["[", "]", " "], "")}"
  end

  # Callbacks
  @impl true
  def init(opts) do
    tick_interval = Keyword.get(opts, :tick_interval, @default_tick_interval)
    pubsub_channel = Keyword.get(opts, :pubsub_channel, @fsm_updates_channel)

    # IO.puts("FSM init: opts=#{inspect(opts)}, pubsub_channel=#{pubsub_channel}")

    # If no custom channel is provided and this is not the global FSM,
    # use a PID-based channel to avoid interference
    final_channel = if pubsub_channel == @fsm_updates_channel do
      # Check if this is the global FSM by checking if it's registered with the module name
      current_pid = self()
      case Process.whereis(__MODULE__) do
        ^current_pid ->
          @fsm_updates_channel  # This is the global FSM (pinned match)
        _ ->
          get_channel_for_pid(current_pid)  # This is a test FSM, use PID-based channel
      end
    else
      pubsub_channel  # Use the explicitly provided channel
    end
    {:ok, :waiting, %{tick_interval: tick_interval, pubsub_channel: final_channel}}
  end

  # inform the supervisor about the child spec
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  @impl true
  def callback_mode, do: :state_functions

  # State: Waiting
  def waiting(:cast, :start, data) do
    tick_interval = Map.get(data, :tick_interval, @default_tick_interval)
    publish_state_change({:working, 10}, data)
    {:next_state, :working, Map.put(data, :count, 10), {:state_timeout, tick_interval, :tick}}
  end

  def waiting(:cast, :abort, data) do
    publish_fsm_error("Cannot abort while in :waiting state", data)
    :keep_state_and_data
  end

  def waiting(_event, _content, _data) do
    :keep_state_and_data
  end

  # State: Working
  def working(:state_timeout, :tick, %{count: 1} = data) do
    # when finished
    publish_state_change(:waiting, data)
    {:next_state, :waiting, Map.delete(data, :count)}
  end

  def working(:state_timeout, :tick, %{count: count, tick_interval: tick_interval} = data) when count > 1 do
    new_count = count - 1
    publish_state_change({:working, new_count}, data)
    {:keep_state, Map.put(data, :count, new_count), {:state_timeout, tick_interval, :tick}}
  end

  def working(:state_timeout, :tick, data) do
    # Handle case where count is not in data (shouldn't happen but for safety)
    publish_state_change(:waiting, data)
    {:next_state, :waiting, data}
  end

  def working(:cast, :abort, data) do
    tick_interval = Map.get(data, :tick_interval, @default_tick_interval)
    publish_state_change(:aborting, data)
    {:next_state, :aborting, Map.delete(data, :count), {:state_timeout, tick_interval, :linger}}
  end

  def working(_event, _content, _data) do
    :keep_state_and_data
  end

  # State: Aborting
  def aborting(:state_timeout, :linger, data) do
    publish_state_change(:waiting, data)
    {:next_state, :waiting, data}
  end

  def aborting(_event, _content, _data) do
    :keep_state_and_data
  end

  # Handle get_state call - works in state_functions mode
  def handle_call(:get_state, _from, state, data) do
    {:reply, {state, data}, state, data}
  end

  defp publish_state_change(new_state, %{pubsub_channel: channel}) do
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      channel,
      {:new_state, new_state}
    )
  end

  defp publish_fsm_error(error, %{pubsub_channel: channel}) do
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      channel,
      {:fsm_error, error}
    )
  end
end
