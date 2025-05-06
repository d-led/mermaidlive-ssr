defmodule MermaidLiveSsr.MermaidServerClient do
  @moduledoc """
  A GenServer-based client for interacting with the Mermaid server.
  """

  use GenServer
  require Logger

  # hardcoded for now
  @server_url "http://localhost:10011/generate"

  ## Public API

  @doc """
  Starts the MermaidServerClient GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Sends a graph definition to the Mermaid server and returns the response.

  ## Parameters
  - `graph`: A string containing the Mermaid graph definition.

  ## Returns
  - `{:ok, svg}` on success.
  - `{:error, reason}` on failure.
  """
  def render_graph(graph) when is_binary(graph) do
    GenServer.call(__MODULE__, {:render_graph, graph})
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    Logger.info("MermaidServerClient started")
    {:ok, state}
  end

  @impl true
  def handle_call({:render_graph, graph}, _from, state) do
    response =
      case Req.post(@server_url, body: graph, headers: [{"Content-Type", "text/plain"}]) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("Failed to render graph. Status: #{status}, Body: #{body}")
          {:error, :server_error}

        {:error, reason} ->
          Logger.error("HTTP request failed: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, response, state}
  end
end
