defmodule MermaidLiveSsr.FsmRendering do
  use GenServer

  require Logger

  @fsm_updates_channel "fsm_updates"
  @rendered_graph_channel "rendered_graph"

  def start_link(_) do
    Logger.info("Starting FsmRendering")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @waiting_state "waiting"

  @placeholder """
  <strong>Trying to render the FSM.<br>Please hold the line...</strong>
  """

  # Public API
  def get_last_rendered_diagram do
    GenServer.call(__MODULE__, :get_last_rendered_diagram, 1_000)
  end

  def send_command(command) do
    MermaidLiveSsr.CountdownFSM.send_command(MermaidLiveSsr.CountdownFSM, command)
  end

  # Removed render_fsm_state - FSM rendering should be handled by the FSM itself


  @impl true
  def init(state) do
    # Just render the initial waiting state, no automatic countdown
    send(self(), {:render_fsm, @waiting_state})
    Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, @fsm_updates_channel)

    {:ok,
     Map.merge(
       state,
       %{
         last_state_seen: @waiting_state,
         last_rendered_diagram: @placeholder,
         counter: 0
       }
     )}
  end

  @impl true
  def handle_info({:render_fsm}, %{last_state_seen: last_state_seen} = state) do
    handle_info({:render_fsm, last_state_seen}, state)
  end

  @impl true
  def handle_info({:render_fsm, fsm_state}, state) do
    rendered_graph = MermaidliveSsr.PreRenderedSvg.render_state(fsm_state, state.counter)

    case rendered_graph do
      {:ok, svg} ->
        # Use global channel for global FSM
        Phoenix.PubSub.broadcast(
          MermaidLiveSsr.PubSub,
          @rendered_graph_channel,
          {:rendered_graph, svg}
        )

        {:noreply, %{state | last_rendered_diagram: svg, last_state_seen: fsm_state}}

      {:error, reason} ->
        Logger.error("Failed to render FSM: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:new_state, fsm_state}, state) do
    # Extract counter from FSM state if it's a working state with counter
    counter = case fsm_state do
      {:working, count} -> count
      _ -> 0
    end
    handle_info({:render_fsm, fsm_state}, %{state | counter: counter})
  end

  @impl true
  def handle_info({:fsm_error, error}, state) do
    # Log FSM errors but don't crash
    Logger.warning("FSM Error: #{error}")
    {:noreply, state}
  end


  @impl true
  def handle_info(:reset_counter, state) do
    # Reset counter and go back to waiting
    new_state = %{state | counter: 0, last_state_seen: "waiting"}
    handle_info({:render_fsm, "waiting"}, new_state)
  end

  # Removed timing-related handlers - FSM should handle all timing

  @impl true
  def handle_call(:get_last_rendered_diagram, _from, state) do
    {:reply, {:ok, state.last_rendered_diagram}, state}
  end

  @impl true
  def handle_cast({:command, command}, state) do
    # Delegate to CountdownFSM
    MermaidLiveSsr.CountdownFSM.send_command(MermaidLiveSsr.CountdownFSM, command)
    {:noreply, state}
  end

  # Removed isolated command handling - this should be done by actual FSM instances

end
