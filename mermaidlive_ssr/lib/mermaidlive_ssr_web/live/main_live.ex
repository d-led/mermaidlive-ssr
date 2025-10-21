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
    # Fast for testing
    tick_interval = Keyword.get(opts, :tick_interval, 100)

    pubsub_channel =
      Keyword.get(opts, :pubsub_channel, "test_fsm_#{System.unique_integer([:positive])}")

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
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, fsm_channel)
      # Subscribe to global events channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "events")
      # Subscribe to presence updates
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "presence_updates")
      # Track this visitor
      track_visitor(socket)
      # Load initial values
      send(self(), :load_initial_values)
      send(self(), {:fetch_last_rendered_diagram, fsm_ref})
    end

    {:ok,
     socket
     |> assign(:diagram, "<strong>Nothing here yet...</strong>")
     |> assign(:state, "waiting")
     |> assign(:counter, 0)
     |> assign(:fsm_ref, fsm_ref)
     |> assign(:fsm_channel, fsm_channel)
     |> assign(:pubsub_channel, pubsub_channel)
     |> assign(:last_event, "")
     |> assign(:last_error, "")
     |> assign(:visitors_active, 0)
     |> assign(:visitors_cluster, 0)
     |> assign(:replicas, "1")
     |> assign(:total_visitors, 0)}
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
            # Fallback to default if process not found
            "fsm_updates"

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
    {state_name, counter} =
      case new_state do
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

  @impl true
  def handle_info({:fsm_error, error_message}, socket) do
    {:noreply, assign(socket, :last_error, error_message)}
  end

  @impl true
  def handle_info(:load_initial_values, socket) do
    # Get initial values from Presence
    presences = MermaidLiveSsrWeb.Presence.list("visitors")
    active_count = map_size(presences)
    
    # Get current FSM state for initial LastSeenState
    current_state = case socket.assigns.fsm_ref do
      fsm_ref when is_pid(fsm_ref) ->
        if Process.alive?(fsm_ref) do
          MermaidLiveSsr.CountdownFSM.get_state(fsm_ref)
        else
          :waiting
        end
      _ ->
        :waiting  # Default fallback
    end
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    last_seen_state = "#{timestamp}: LastSeenState [param: #{current_state}]"
    
    {:noreply,
     socket
     |> assign(:visitors_active, active_count)
     |> assign(:visitors_cluster, active_count)
     |> assign(:total_visitors, active_count)  # Will be updated by presence messages
     |> assign(:last_event, last_seen_state)}
  end

  @impl true
  def handle_info({:presence_update, %{active_count: active, total_count: total, cluster_count: cluster}}, socket) do
    {:noreply,
     socket
     |> assign(:visitors_active, active)
     |> assign(:visitors_cluster, cluster)  # This should be different from active in a real cluster
     |> assign(:total_visitors, total)}
  end

  @impl true
  def handle_info({:last_event, event}, socket) do
    {:noreply, assign(socket, :last_event, event)}
  end

  @impl true
  def handle_info({:last_error, error}, socket) do
    {:noreply, assign(socket, :last_error, error)}
  end

  @impl true
  def handle_info({:visitors_active, count}, socket) do
    {:noreply, assign(socket, :visitors_active, count)}
  end

  @impl true
  def handle_info({:visitors_cluster, count}, socket) do
    {:noreply, assign(socket, :visitors_cluster, count)}
  end

  @impl true
  def handle_info({:replicas, replicas}, socket) do
    {:noreply, assign(socket, :replicas, replicas)}
  end

  @impl true
  def handle_info({:total_visitors, count}, socket) do
    {:noreply, assign(socket, :total_visitors, count)}
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

  # Track visitor using Phoenix Presence
  defp track_visitor(_socket) do
    visitor_id = "visitor_#{System.unique_integer([:positive])}"

    # Track in Presence - this will trigger presence_diff events
    MermaidLiveSsrWeb.Presence.track(
      self(),
      "visitors",
      visitor_id,
      %{
        online_at: System.system_time(:second),
        pid: self()
      }
    )
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
    <main role="main" class="container">
      <div class="container">
        <h4>Mermaid.js Server-Side Pre-rendered Live Demo</h4>
        <p>
          <small>Click on the edges (guards) to interact with the state machine.</small>
          <br />
          <small>State machine is local to the server replica.</small>
          <br />
          <small>Open the page in multiple browsers and observe interactive changes.</small>
          <br />
          <small>Go offline and back online to experiment with re-connection.</small>
        </p>
        <div class="d-flex flex-row mt-2 mb-2" id="graph">
          <.live_component
            module={MermaidLiveSsrWeb.Components.PreRenderedStateMachine}
            id="state-machine"
            state={@state}
            counter={@counter}
          />
        </div>

        <h4>Server-side updates & info</h4>

        <div id="alerts">
          <div id="alert-placeholder"></div>
          <div class="alert alert-warning" role="alert" id="offline-alert" style="display: none;">
            Offline, hold on ...
          </div>
          <div class="alert alert-success fade" id="connected-alert" style="display: none;">
            Connected
          </div>
        </div>

        <div class="table-responsive-sm d-flex flex-row mt-2 mb-2">
          <table class="table table-fit">
            <thead class="thead-light">
              <tr>
                <th scope="col" style="display: none;">Info</th>
                <th scope="col" style="display: none;">Value</th>
              </tr>
            </thead>
            <tbody>
              <tr class="monospaced">
                <td>Last event</td>
                <td><span id="last-event"><%= @last_event %></span></td>
              </tr>
              <tr class="monospaced">
                <td>Last error</td>
                <td><span id="delayed-text"><%= @last_error %></span></td>
              </tr>
              <tr class="monospaced">
                <td>Visitors active on this replica</td>
                <td><span id="visitors-active"><%= @visitors_active %></span></td>
              </tr>
              <tr class="monospaced">
                <td>Visitors active in the cluster</td>
                <td><span id="visitors-active-cluster"><%= @visitors_cluster %></span></td>
              </tr>
              <tr class="monospaced">
                <td>Server revision</td>
                <td><span id="server-revision">dev</span></td>
              </tr>
              <tr class="monospaced">
                <td>Source</td>
                <td>
                  <a href="https://github.com/d-led/mermaidlive-ssr">
                    github.com/d-led/mermaidlive-ssr
                  </a>
                </td>
              </tr>
              <tr class="monospaced">
                <td>Replicas</td>
                <td><span id="replicas"><%= @replicas %></span></td>
              </tr>
              <tr class="monospaced">
                <td>Total started connections</td>
                <td><span id="total-visitors"><%= @total_visitors %></span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </main>
    """
  end
end
