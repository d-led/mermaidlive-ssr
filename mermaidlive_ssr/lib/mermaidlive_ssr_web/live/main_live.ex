defmodule MermaidLiveSsrWeb.MainLive do
  use MermaidLiveSsrWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "rendered_graphs")
      send(self(), :fetch_last_rendered_diagram)
    end

    {:ok, assign(socket, diagram: "<strong>Nothing here yet...</strong>")}
  end

  @impl true
  def handle_info(:fetch_last_rendered_diagram, socket) do
    diagram =
      case MermaidLiveSsr.FsmRendering.get_last_rendered_diagram() do
        {:ok, diagram} -> diagram
        _ -> "<strong>No diagram available<strong>"
      end

    {:noreply, assign(socket, diagram: diagram)}
  end

  @impl true
  def handle_info({:rendered_graph, svg}, socket) do
    {:noreply, assign(socket, diagram: svg)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4 w-full h-full">
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Graph</div>
        {Phoenix.HTML.raw(@diagram)}
      </div>
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Intro</div>
        <p>Click on the edges (guards) to interact with the state machine.</p>
        <p>State machine is local to the server replica.</p>
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
