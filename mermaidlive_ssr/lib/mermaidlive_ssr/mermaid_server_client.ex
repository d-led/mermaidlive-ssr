defmodule MermaidLiveSsr.MermaidServerClient do
  @moduledoc """
  A GenServer-based client for interacting with the Mermaid server.
  """

  use GenServer
  require Logger

  ## Public API

  @doc """
  Starts the MermaidServerClient GenServer.

  ## Options
  - `:server_url` - The mermaid server url including /generate.

  """
  def start_link(opts) do
    server_url = Keyword.fetch!(opts, :server_url) || "http://localhost:10011/generate"
    # Ensure the server_url is a valid URL
    GenServer.start_link(__MODULE__, %{server_url: server_url}, name: __MODULE__)
  end

  @doc """
  Sends a graph definition to the Mermaid server and returns the response.

  ## Parameters
  - `graph`: A string containing the Mermaid graph definition.

  ## Returns
  - `{:ok, svg}` on success.
  - `{:error, reason}` on failure.

  ## Example

  ```
  graph = "graph LR\nA-->B\nB-->C"
  {:ok, svg} = MermaidLiveSsr.MermaidServerClient.render_graph(graph)
  ```
  """
  def render_graph(graph) when is_binary(graph) do
    GenServer.call(__MODULE__, {:render_graph, graph})
  end

  ## GenServer Callbacks

  @impl true
  def init(%{server_url: server_url} = state) do
    Logger.info("MermaidServerClient started with server_url: #{server_url}")
    {:ok, state}
  end

  @impl true
  def handle_call({:render_graph, graph}, _from, %{server_url: server_url} = state) do
    response =
      case Req.post(server_url, body: graph, headers: [{"Content-Type", "text/plain"}]) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error(
            "Failed to render graph. Status: #{inspect(status)}, Body: #{inspect(body)}"
          )

          {:error, :server_error}

        {:error, reason} ->
          Logger.error("HTTP request failed: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, response, state}
  end
end
