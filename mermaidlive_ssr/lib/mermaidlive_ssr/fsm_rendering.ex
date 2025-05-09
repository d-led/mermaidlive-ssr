defmodule MermaidLiveSsr.FsmRendering do
  use GenServer

  require Logger

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

  @impl true
  def init(state) do
    Process.send_after(self(), {:render_fsm, @waiting_state}, 10)

    {:ok,
     Map.merge(
       state,
       %{
         last_state_seen: @waiting_state,
         last_rendered_diagram: @placeholder
       }
     )}
  end

  @impl true
  def handle_info({:render_fsm}, %{last_state_seen: last_state_seen} = state) do
    handle_info({:render_fsm, last_state_seen}, state)
  end

  @impl true
  def handle_info({:render_fsm, fsm_state}, state) do
    rendered_graph = MermaidliveSsr.PreRenderedSvg.render_state(fsm_state)

    case rendered_graph do
      {:ok, svg} ->
        Logger.info("Rendered FSM successfully.")

        Phoenix.PubSub.broadcast(
          MermaidLiveSsr.PubSub,
          "rendered_graphs",
          {:rendered_graph, svg}
        )

        {:noreply, %{state | last_rendered_diagram: svg, last_state_seen: fsm_state}}

      {:error, reason} ->
        Logger.error("Failed to render FSM: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_last_rendered_diagram, _from, state) do
    {:reply, {:ok, state.last_rendered_diagram}, state}
  end
end
