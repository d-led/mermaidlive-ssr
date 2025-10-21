defmodule MermaidLiveSsrWeb.MainLive do
  use MermaidLiveSsrWeb, :live_view

  @rendered_graph_channel "rendered_graph"

  # Helper function for testing - create LiveView with custom FSM reference
  def start_link_with_fsm(fsm_ref, _opts \\ []) do
    # For testing, we'll use the URL params approach
    %{"fsm_ref" => fsm_ref}
  end

  # Helper function for testing - create a test FSM with custom configuration
  def create_test_fsm(opts \\ []) do
    tick_interval = Keyword.get(opts, :tick_interval, 100)  # Fast for testing
    pubsub_channel = Keyword.get(opts, :pubsub_channel, "test_fsm_#{System.unique_integer([:positive])}")
    name = Keyword.get(opts, :name, :"test_fsm_#{System.unique_integer([:positive])}")

    MermaidLiveSsr.CountdownFSM.start_link(
      [tick_interval: tick_interval, pubsub_channel: pubsub_channel],
      name
    )
  end

  @impl true
  def mount(params, _session, socket) do
    fsm_ref = get_fsm_ref(params, socket.assigns)
    fsm_channel = get_fsm_channel(fsm_ref)
    pubsub_channel = get_pubsub_channel(params, socket.assigns)

    if connected?(socket) do
      # Subscribe to the FSM-specific channel for state changes
      IO.puts("LiveView subscribing to FSM channel: #{fsm_channel}")
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, fsm_channel)
      send(self(), {:fetch_last_rendered_diagram, fsm_ref})
    end

    {:ok,
     socket
     |> assign(:diagram, "<strong>Nothing here yet...</strong>")
     |> assign(:state, "waiting")
     |> assign(:counter, 0)
     |> assign(:fsm_ref, fsm_ref)
     |> assign(:fsm_channel, fsm_channel)
     |> assign(:pubsub_channel, pubsub_channel)}
  end

  defp get_fsm_ref(params, assigns) do
    cond do
      # Check if FSM ref is already assigned (for testing)
      Map.has_key?(assigns, :fsm_ref) ->
        assigns.fsm_ref
      # Check URL params for FSM reference
      Map.has_key?(params, "fsm_ref") ->
        fsm_ref = params["fsm_ref"]
        if is_binary(fsm_ref) do
          # Try to parse as PID first, then as atom
          case fsm_ref do
            "#PID" <> _ ->
              # This is a PID string, we can't easily parse it back to PID
              # For now, default to global FSM
              MermaidLiveSsr.CountdownFSM
            _ ->
              # Convert to atom (for test FSM names)
              String.to_atom(fsm_ref)
          end
        else
          fsm_ref
        end
      # Default to global FSM
      true ->
        MermaidLiveSsr.CountdownFSM
    end
  end

  defp get_pubsub_channel(params, assigns) do
    cond do
      # Check if channel is already assigned (for testing)
      Map.has_key?(assigns, :pubsub_channel) ->
        assigns.pubsub_channel
      # Check URL params for custom channel
      Map.has_key?(params, "pubsub_channel") ->
        params["pubsub_channel"]
      # Default to rendered graph channel
      true ->
        @rendered_graph_channel
    end
  end

  # Get the appropriate channel for the FSM reference
  defp get_fsm_channel(fsm_ref) do
    cond do
      # If it's the global FSM module, use the default channel
      fsm_ref == MermaidLiveSsr.CountdownFSM ->
        "fsm_updates"
      # If it's a PID, construct channel name based on PID
      is_pid(fsm_ref) ->
        MermaidLiveSsr.CountdownFSM.get_channel_for_pid(fsm_ref)
      # If it's an atom (named process), try to get its PID and then its channel
      is_atom(fsm_ref) ->
        case Process.whereis(fsm_ref) do
          nil ->
            "fsm_updates"  # Fallback to default if process not found
          pid ->
            MermaidLiveSsr.CountdownFSM.get_channel_for_pid(pid)
        end
      # For other cases, use default
      true ->
        "fsm_updates"
    end
  end

  @impl true
  def handle_info({:fetch_last_rendered_diagram, _fsm_ref}, socket) do
    diagram =
      case MermaidLiveSsr.FsmRendering.get_last_rendered_diagram() do
        {:ok, diagram} -> diagram
        _ -> "<strong>No diagram available</strong>"
      end

    {:noreply, assign(socket, diagram: diagram)}
  end

  @impl true
  def handle_info({:rendered_graph, svg}, socket) do
    # Parse the state from the SVG to update our state
    state = extract_state_from_svg(svg)
    counter = extract_counter_from_svg(svg)

    {:noreply,
     socket
     |> assign(:diagram, svg)
     |> assign(:state, state)
     |> assign(:counter, counter)}
  end

  @impl true
  def handle_info({:new_state, new_state}, socket) do
    # Handle direct FSM state changes (for isolated FSMs)
    IO.puts("LiveView received FSM state change: #{inspect(new_state)}")
    {state_name, counter} = case new_state do
      {:working, count} -> {"working", count}
      :working -> {"working", 0}
      :waiting -> {"waiting", 0}
      :aborting -> {"aborting", 0}
      state when is_atom(state) -> {Atom.to_string(state), 0}
    end

    # Render the new state
    case MermaidliveSsr.PreRenderedSvg.render_state(state_name, counter) do
      {:ok, svg} ->
        {:noreply,
         socket
         |> assign(:diagram, svg)
         |> assign(:state, state_name)
         |> assign(:counter, counter)}
      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  # Extract state from SVG by looking for the inProgress class
  defp extract_state_from_svg(svg) do
    cond do
      String.contains?(svg, "state-waiting-4\" class=\"node inProgress") -> "waiting"
      String.contains?(svg, "state-working-5\" class=\"node inProgress") -> "working"
      String.contains?(svg, "state-aborting-4\" class=\"node inProgress") -> "aborting"
      true -> "waiting"
    end
  end

  # Extract counter from SVG by looking for the note content
  defp extract_counter_from_svg(svg) do
    case Regex.run(~r/<p>(\d+)<\/p>/, svg) do
      [_, counter_str] -> String.to_integer(counter_str)
      _ -> 0
    end
  end

  @impl true
  def handle_event("start", _params, socket) do
    # Only allow start if we're in waiting state
    if socket.assigns.state == "waiting" do
      # Send command to FSM
      MermaidLiveSsr.CountdownFSM.send_command(socket.assigns.fsm_ref, :start)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("abort", _params, socket) do
    # Send command to FSM (FSM will validate if abort is allowed)
    MermaidLiveSsr.CountdownFSM.send_command(socket.assigns.fsm_ref, :abort)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4 w-full h-full">
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Graph</div>
        <.live_component
          module={MermaidLiveSsrWeb.Components.PreRenderedStateMachine}
          id="state-machine"
          state={@state}
          counter={@counter}
        />
      </div>
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Intro</div>
        <%!-- <p>Click on the edges (guards) to interact with the state machine.</p> --%>
        <%!-- <p>State machine is local to the server replica.</p> --%>
        <p>Open the page in multiple browsers and observe interactive changes.</p>
        <p>Go offline and back online to experiment with re-connection.</p>
      </div>
      <div class="col-span-2 w-full h-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Status</div>
      </div>
    </div>
    """
  end
end
