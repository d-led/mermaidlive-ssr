defmodule MermaidLiveSsrWeb.Live.Constants do
  @moduledoc """
  Centralized constants for LiveView components.

  This module contains all channel names, topic names, and other constants
  used throughout the LiveView system to avoid magic strings and improve
  maintainability.
  """

  # PubSub Channels
  @doc "Default channel for rendered graphs"
  def rendered_graph_channel, do: "rendered_graph"

  @doc "Default channel for FSM updates"
  def fsm_updates_channel, do: "fsm_updates"

  @doc "Global events channel"
  def events_channel, do: "events"

  @doc "Presence updates channel"
  def presence_updates_channel, do: "presence_updates"

  @doc "Visitor counter updates channel"
  def visitor_counter_updates_channel, do: "visitor_counter_updates"

  # Presence Topics
  @doc "Topic for visitor presence tracking"
  def visitors_topic, do: "visitors"

  # Default Values
  @doc "Default server revision"
  def default_server_revision, do: "dev"

  @doc "Default number of replicas"
  def default_replicas, do: "1"

  # State Names
  @doc "Waiting state name"
  def waiting_state, do: "waiting"

  @doc "Working state name"
  def working_state, do: "working"

  @doc "Aborting state name"
  def aborting_state, do: "aborting"

  # Default Messages
  @doc "Default diagram message when nothing is rendered"
  def default_diagram_message, do: "<strong>Nothing here yet...</strong>"

  @doc "Default message when no diagram is available"
  def no_diagram_message, do: "<strong>No diagram available</strong>"

  # SVG Parsing Patterns
  @doc "Regex pattern for extracting counter from SVG"
  def counter_regex, do: ~r/<p>(\d+)<\/p>/

  # SVG State Classes
  @doc "SVG class pattern for waiting state"
  def waiting_state_class, do: "state-waiting-4\" class=\"node inProgress"

  @doc "SVG class pattern for working state"
  def working_state_class, do: "state-working-5\" class=\"node inProgress"

  @doc "SVG class pattern for aborting state"
  def aborting_state_class, do: "state-aborting-4\" class=\"node inProgress"
end
