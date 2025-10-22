defmodule MermaidLiveSsrWeb.MainLive do
  use MermaidLiveSsrWeb, :live_view

  # credo:disable-for-next-line Credo.Check.Readability.AliasOrder
  alias MermaidLiveSsrWeb.Live.{
    Constants,
    FsmResolver,
    SvgParser,
    SubscriptionManager,
    VisitorTracker
  }

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
    fsm_ref = FsmResolver.get_fsm_ref(params, socket.assigns)
    fsm_channel = FsmResolver.get_fsm_channel(fsm_ref)
    pubsub_channel = FsmResolver.get_pubsub_channel(params, socket.assigns)

    # Load initial values
    require Logger
    Logger.info("LiveView mount: connected?=#{connected?(socket)}")

    {active_count, total_visitors} =
      if connected?(socket) do
        # Subscribe to all necessary channels
        SubscriptionManager.subscribe_to_channels(fsm_channel)

        # Load initial values and track visitor
        {active_count, total_visitors} = VisitorTracker.load_initial_counts(true)

        # Debug logging
        require Logger

        Logger.info(
          "LiveView loaded initial values: active_count=#{active_count}, total_visitors=#{total_visitors}"
        )

        send(self(), {:fetch_last_rendered_diagram, fsm_ref})

        # Show the persisted value initially, PubSub will update it
        {active_count, total_visitors}
      else
        # For non-connected state (SSR), read the persisted total via GenServer call
        VisitorTracker.load_initial_counts(false)
      end

    {:ok,
     socket
     |> assign(:diagram, Constants.default_diagram_message())
     |> assign(:state, Constants.waiting_state())
     |> assign(:counter, 0)
     |> assign(:fsm_ref, fsm_ref)
     |> assign(:fsm_channel, fsm_channel)
     |> assign(:pubsub_channel, pubsub_channel)
     |> assign(:last_event, "")
     |> assign(:last_error, "")
     |> assign(:visitors_active, active_count)
     |> assign(:visitors_cluster, active_count)
     |> assign(:replicas, Constants.default_replicas())
     |> assign(:total_visitors, total_visitors)}
  end

  @impl true
  def handle_info({:fetch_last_rendered_diagram, _fsm_ref}, socket) do
    diagram =
      case MermaidLiveSsr.FsmRendering.get_last_rendered_diagram() do
        {:ok, diagram} -> diagram
        _ -> Constants.no_diagram_message()
      end

    {:noreply, assign(socket, diagram: diagram)}
  end

  @impl true
  def handle_info({:rendered_graph, svg}, socket) do
    # Parse the state from the SVG to update our state
    state = SvgParser.extract_state_from_svg(svg)
    counter = SvgParser.extract_counter_from_svg(svg)

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
        {:working, count} -> {Constants.working_state(), count}
        :working -> {Constants.working_state(), 0}
        :waiting -> {Constants.waiting_state(), 0}
        :aborting -> {Constants.aborting_state(), 0}
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
  def handle_info(
        {:presence_update, %{active_count: active, total_count: _total, cluster_count: cluster}},
        socket
      ) do
    {
      :noreply,
      socket
      |> assign(:visitors_active, active)
      # This should be different from active in a real cluster
      |> assign(:visitors_cluster, cluster)
      # Don't override total_visitors from Presence - only use CRDT counter
    }
  end

  @impl true
  def handle_info({:visitor_count_updated, total_count}, socket) do
    require Logger
    Logger.info("LiveView received visitor_count_updated: #{total_count}")
    {:noreply, assign(socket, :total_visitors, total_count)}
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

  @impl true
  def handle_event("start", _params, socket) do
    # Only allow start if we're in waiting state
    if socket.assigns.state == Constants.waiting_state() do
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
                <td><span id="last-event">{@last_event}</span></td>
              </tr>
              <tr class="monospaced">
                <td>Last error</td>
                <td><span id="delayed-text">{@last_error}</span></td>
              </tr>
              <tr class="monospaced">
                <td>Visitors active on this replica</td>
                <td><span id="visitors-active">{@visitors_active}</span></td>
              </tr>
              <tr class="monospaced">
                <td>Visitors active in the cluster</td>
                <td><span id="visitors-active-cluster">{@visitors_cluster}</span></td>
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
                <td><span id="replicas">{@replicas}</span></td>
              </tr>
              <tr class="monospaced">
                <td>Total started connections</td>
                <td><span id="total-visitors">{@total_visitors}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </main>
    """
  end
end
