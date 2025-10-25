defmodule MermaidLiveSsrWeb.Live.FsmResolver do
  @moduledoc """
  Handles FSM reference resolution and channel management for LiveView components.

  This module extracts the logic for determining which FSM to use and how to
  communicate with it, making the LiveView more focused on presentation.
  """

  alias MermaidLiveSsrWeb.Live.Constants

  @doc """
  Resolves the FSM reference from params and assigns.

  ## Examples

      iex> FsmResolver.get_fsm_ref(%{"fsm_ref" => "test_fsm"}, %{})
      :test_fsm

      iex> FsmResolver.get_fsm_ref(%{}, %{fsm_ref: :existing_fsm})
      :existing_fsm

      iex> FsmResolver.get_fsm_ref(%{}, %{})
      MermaidLiveSsr.CountdownFSM
  """
  def get_fsm_ref(params, assigns) do
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

      # Default to global FSM - get PID from supervisor since name registration is broken
      true ->
        get_global_fsm_pid()
    end
  end

  @doc """
  Gets the pubsub channel from params and assigns.

  ## Examples

      iex> FsmResolver.get_pubsub_channel(%{"pubsub_channel" => "custom"}, %{})
      "custom"

      iex> FsmResolver.get_pubsub_channel(%{}, %{pubsub_channel: "existing"})
      "existing"

      iex> FsmResolver.get_pubsub_channel(%{}, %{})
      "rendered_graph"
  """
  def get_pubsub_channel(params, assigns) do
    cond do
      # Check if channel is already assigned (for testing)
      Map.has_key?(assigns, :pubsub_channel) ->
        assigns.pubsub_channel

      # Check URL params for custom channel
      Map.has_key?(params, "pubsub_channel") ->
        params["pubsub_channel"]

      # Default to rendered graph channel
      true ->
        Constants.rendered_graph_channel()
    end
  end

  @doc """
  Gets the appropriate channel for the FSM reference.

  ## Examples

      iex> FsmResolver.get_fsm_channel(MermaidLiveSsr.CountdownFSM)
      "fsm_updates"

      iex> FsmResolver.get_fsm_channel(:test_fsm)
      "fsm_updates"  # when process not found
  """
  def get_fsm_channel(fsm_ref) do
    cond do
      # If it's the global FSM module, use the default channel
      fsm_ref == MermaidLiveSsr.CountdownFSM ->
        Constants.fsm_updates_channel()

      # If it's a PID, construct channel name based on PID
      is_pid(fsm_ref) ->
        MermaidLiveSsr.CountdownFSM.get_channel_for_pid(fsm_ref)

      # If it's an atom (named process), try to get its PID and then its channel
      is_atom(fsm_ref) ->
        case Process.whereis(fsm_ref) do
          nil ->
            # Fallback to default if process not found
            Constants.fsm_updates_channel()

          pid ->
            MermaidLiveSsr.CountdownFSM.get_channel_for_pid(pid)
        end

      # For other cases, use default
      true ->
        Constants.fsm_updates_channel()
    end
  end

  @doc """
  Gets the PID of the global FSM from the supervisor.
  """
  def get_global_fsm_pid do
    children = Supervisor.which_children(MermaidLiveSsr.Supervisor)
    fsm_entry = Enum.find(children, fn {id, _pid, _type, _modules} -> id == MermaidLiveSsr.CountdownFSM end)

    if fsm_entry do
      {_id, fsm_pid, _type, _modules} = fsm_entry
      fsm_pid
    else
      # Fallback to module name if not found
      MermaidLiveSsr.CountdownFSM
    end
  end
end
