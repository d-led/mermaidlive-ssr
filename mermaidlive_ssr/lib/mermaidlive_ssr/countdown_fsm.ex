defmodule MermaidLiveSsr.CountdownFSM do
  @moduledoc """
  A finite state machine for countdown operations.

  This module implements a countdown state machine that can transition between
  waiting, working, and aborting states. It's used to manage countdown timers
  for visitor interactions.
  """
  use VirtualTimeGenStateMachine, callback_mode: :handle_event_function

  @fsm_updates_channel "fsm_updates"
  @default_tick_interval 100
  # Much faster for testing
  @test_tick_interval 10

  # Public API
  def start_link(opts \\ [], name \\ __MODULE__) do
    VirtualTimeGenStateMachine.start_link(__MODULE__, opts, [name: name])
  end

  # Send command to FSM (supports both named and PID references)
  def send_command(fsm \\ __MODULE__, command) do
    VirtualTimeGenStateMachine.cast(fsm, command)
  end

  # Get current state of FSM (supports both named and PID references)
  def get_state(fsm \\ __MODULE__) do
    VirtualTimeGenStateMachine.call(fsm, :get_state)
  end

  # Helper function to get the channel for a specific FSM PID
  def get_channel_for_pid(pid) when is_pid(pid) do
    "fsm_#{:erlang.pid_to_list(pid) |> List.to_string() |> String.replace(["[", "]", " "], "")}"
  end

  # Helper function to get appropriate tick interval based on environment
  defp get_tick_interval(opts) do
    case Keyword.get(opts, :tick_interval) do
      nil ->
        # Use test interval in test environment, default in others
        if Mix.env() == :test do
          @test_tick_interval
        else
          @default_tick_interval
        end

      interval ->
        interval
    end
  end

  # Callbacks
  @impl true
  def init(opts) do
    tick_interval = get_tick_interval(opts)
    pubsub_channel = Keyword.get(opts, :pubsub_channel, @fsm_updates_channel)

    # IO.puts("FSM init: opts=#{inspect(opts)}, pubsub_channel=#{pubsub_channel}")

    # If no custom channel is provided and this is not the global FSM,
    # use a PID-based channel to avoid interference
    final_channel =
      if pubsub_channel == @fsm_updates_channel do
        # Check if this is the global FSM by checking if it's registered with the module name
        current_pid = self()

        case Process.whereis(__MODULE__) do
          ^current_pid ->
            # This is the global FSM (pinned match)
            @fsm_updates_channel

          _ ->
            # This is a test FSM, use PID-based channel
            get_channel_for_pid(current_pid)
        end
      else
        # Use the explicitly provided channel
        pubsub_channel
      end

    {:ok, :waiting, %{tick_interval: tick_interval, pubsub_channel: final_channel}}
  end

  # inform the supervisor about the child spec
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args, __MODULE__]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  # Handle events for all states
  def handle_event(:cast, :start, :waiting, data) do
    tick_interval = Map.get(data, :tick_interval, @default_tick_interval)
    publish_state_change({:working, 10}, data)

    # Schedule the first tick using virtual time
    VirtualTimeGenStateMachine.send_after(self(), :tick, tick_interval)
    {:next_state, :working, Map.put(data, :count, 10)}
  end

  def handle_event(:cast, :abort, :waiting, data) do
    publish_fsm_error("Cannot abort while in :waiting state", data)
    :keep_state_and_data
  end

  def handle_event(:info, :tick, :working, %{count: 1} = data) do
    # when finished - publish WorkDone event
    publish_work_done_event(data)
    publish_state_change(:waiting, data)
    {:next_state, :waiting, Map.delete(data, :count)}
  end

  def handle_event(:info, :tick, :working, %{count: count, tick_interval: tick_interval} = data)
      when count > 1 do
    new_count = count - 1
    # Publish state change first, then tick event
    publish_state_change({:working, new_count}, data)
    # Publish tick event after state change to ensure it's the last event
    publish_tick_event(count, data)

    # Schedule the next tick using virtual time
    VirtualTimeGenStateMachine.send_after(self(), :tick, tick_interval)
    {:keep_state, Map.put(data, :count, new_count)}
  end

  def handle_event(:info, :tick, :working, data) do
    # Handle case where count is not in data (shouldn't happen but for safety)
    publish_state_change(:waiting, data)
    {:next_state, :waiting, data}
  end

  def handle_event(:cast, :abort, :working, data) do
    tick_interval = Map.get(data, :tick_interval, @default_tick_interval)
    publish_state_change(:aborting, data)

    # Schedule linger timeout using virtual time
    VirtualTimeGenStateMachine.send_after(self(), :linger, tick_interval)
    {:next_state, :aborting, Map.delete(data, :count)}
  end

  def handle_event(:cast, :start, :working, data) do
    publish_fsm_error("Cannot start while in :working state", data)
    :keep_state_and_data
  end

  def handle_event(:info, :linger, :aborting, data) do
    # Publish WorkAborted event before transitioning to waiting
    publish_work_aborted_event(data)
    publish_state_change(:waiting, data)
    {:next_state, :waiting, data}
  end

  def handle_event(:cast, :start, :aborting, data) do
    publish_fsm_error("Cannot start while in :aborting state", data)
    :keep_state_and_data
  end

  def handle_event(:cast, :abort, :aborting, data) do
    publish_fsm_error("Cannot abort while in :aborting state", data)
    :keep_state_and_data
  end

  # Handle get_state call - works in handle_event_function mode
  def handle_event({:call, from}, :get_state, state, data) do
    {:keep_state_and_data, [{:reply, from, {state, data}}]}
  end

  # Catch-all for unhandled events
  def handle_event(_event_type, _event_content, _state, _data) do
    :keep_state_and_data
  end

  defp publish_state_change(new_state, %{pubsub_channel: channel}) do
    # Publish to FSM channel
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      channel,
      {:new_state, new_state}
    )

    # Also publish to global events channel for tracking
    {event_name, param} =
      case new_state do
        {:working, _count} -> {"WorkStarted", ""}
        # Changed from LastSeenState to WorkDone
        :waiting -> {"WorkDone", ""}
        :aborting -> {"WorkAbortRequested", ""}
      end

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    event_line =
      if param != "" do
        "#{timestamp}: #{event_name} [param: #{param}]"
      else
        "#{timestamp}: #{event_name}"
      end

    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:last_event, event_line}
    )
  end

  defp publish_tick_event(count, %{pubsub_channel: _channel}) do
    # Publish tick event to global events channel
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    tick_line = "#{timestamp}: Tick [param: #{count}]"

    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:last_event, tick_line}
    )
  end

  defp publish_work_aborted_event(%{pubsub_channel: _channel}) do
    # Publish WorkAborted event to global events channel
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    aborted_line = "#{timestamp}: WorkAborted"

    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:last_event, aborted_line}
    )
  end

  defp publish_work_done_event(%{pubsub_channel: _channel}) do
    # Publish WorkDone event to global events channel
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    done_line = "#{timestamp}: WorkDone"

    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:last_event, done_line}
    )
  end

  defp publish_fsm_error(error, %{pubsub_channel: channel}) do
    # Publish to FSM channel
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      channel,
      {:fsm_error, error}
    )

    # Also publish to global events channel for tracking
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    error_line = "#{timestamp}: RequestIgnored [reason: #{error}]"

    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      "events",
      {:last_error, error_line}
    )
  end
end
