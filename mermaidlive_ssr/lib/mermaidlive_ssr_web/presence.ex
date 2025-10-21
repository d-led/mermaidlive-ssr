defmodule MermaidLiveSsrWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :mermaidlive_ssr,
    pubsub_server: MermaidLiveSsr.PubSub
end
