defmodule MermaidLiveSsrWeb.MainLive do
  use MermaidLiveSsrWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # nothing for now
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4 w-full h-full">
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Graph</div>
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
