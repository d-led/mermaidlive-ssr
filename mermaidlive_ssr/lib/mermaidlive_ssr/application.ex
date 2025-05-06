defmodule MermaidLiveSsr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children =
      [
        MermaidLiveSsrWeb.Telemetry
      ] ++
        clustering() ++
        [
          {Phoenix.PubSub, name: MermaidLiveSsr.PubSub},
          # Start MermaidServerClient as a globally registered service
          {MermaidLiveSsr.MermaidServerClient, []},
          # Start to serve requests, typically the last entry
          MermaidLiveSsrWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MermaidLiveSsr.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MermaidLiveSsrWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp clustering() do
    dns_query = Application.get_env(:mermaidlive_ssr, :dns_cluster_query)
    Logger.info("DNS Cluster Query: #{inspect(dns_query)}")
    if dns_query do
      [
        {DNSCluster, query: Application.get_env(:mermaidlive_ssr, :dns_cluster_query) || :ignore}
      ]
    else
      []
    end
  end
end
