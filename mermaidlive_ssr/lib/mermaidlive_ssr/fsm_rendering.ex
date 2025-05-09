defmodule MermaidLiveSsr.FsmRendering do
  use GenServer

  require Logger

  def start_link(opts) do
    server_client_module =
      case Keyword.fetch(opts, :mermaid_client_module) do
        {:ok, module} -> module
        :error -> MermaidLiveSsr.MermaidServerClient
      end

    Logger.info("Starting FsmRendering with client module: #{inspect(server_client_module)}")

    GenServer.start_link(__MODULE__, %{server_client_module: server_client_module},
      name: __MODULE__
    )
  end

  @waiting_state "waiting"

  @placeholder """
  <strong>Trying to render the FSM.<br>Please hold the line...</strong>
  """

  # Public API
  def get_last_rendered_diagram do
    GenServer.call(__MODULE__, :get_last_rendered_diagram, 30_000)
  end

  @impl true
  def init(state) do
    Process.send_after(self(), {:render_fsm, @waiting_state}, 100)

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
  def handle_info({:render_fsm, fsm_state}, %{server_client_module: server_client_module} = state) do
    input = mermaid_definition_for_state(fsm_state)
    rendered_graph = server_client_module.render_graph(input)

    case rendered_graph do
      {:ok, svg} ->
        Logger.info("Rendered FSM successfully.")

        fixed_svg = MermaidLiveSsr.SvgManipulator.fix_node_text_dimensions(svg)

        Phoenix.PubSub.broadcast(
          MermaidLiveSsr.PubSub,
          "rendered_graphs",
          {:rendered_graph, fixed_svg}
        )

        {:noreply, %{state | last_rendered_diagram: fixed_svg, last_state_seen: fsm_state}}

        {:error, %Req.TransportError{reason: :timeout}}
        Logger.error("Failed to render FSM due to time-out, retrying...")
        Process.send_after(self(), {:render_fsm}, 3_000)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to render FSM: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_last_rendered_diagram, _from, state) do
    {:reply, {:ok, state.last_rendered_diagram}, state}
  end

  defp mermaid_definition_for_state(_current_state) do
    """
    stateDiagram-v2
      [*] --> waiting
      waiting --> working : start
      working --> aborting : abort
      working --> waiting
      aborting --> waiting
    """
  end
end
