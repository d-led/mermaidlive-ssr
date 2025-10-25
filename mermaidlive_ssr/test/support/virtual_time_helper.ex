defmodule MermaidLiveSsr.VirtualTimeHelper do
  @moduledoc """
  Helper module for setting up virtual time in tests.

  This module provides utilities for configuring virtual clocks
  and managing virtual time in FSM tests.
  """

  @doc """
  Sets up a virtual clock for testing and configures the FSM to use it.

  Returns a tuple with the clock PID and a cleanup function.
  """
  def setup_virtual_clock do
    {:ok, clock} = VirtualClock.start_link()
    {clock, fn -> GenServer.stop(clock) end}
  end

  @doc """
  Advances virtual time by the specified milliseconds.
  """
  def advance_time(clock, milliseconds) do
    VirtualClock.advance(clock, milliseconds)
  end

  @doc """
  Advances virtual time to the next scheduled event.
  """
  def advance_to_next_event(clock) do
    VirtualClock.advance_to_next(clock)
  end

  @doc """
  Gets the current virtual time.
  """
  def current_time(clock) do
    VirtualClock.now(clock)
  end

  @doc """
  Runs a test with virtual time setup and cleanup.

  The function receives a tuple of {clock, cleanup_fn} and should return
  the test result. Cleanup is automatically performed.
  """
  def with_virtual_clock(fun) do
    {clock, cleanup} = setup_virtual_clock()

    try do
      fun.({clock, cleanup})
    after
      cleanup.()
    end
  end

  @doc """
  Creates a test FSM with virtual time enabled.

  This is a convenience function that sets up both the virtual clock
  and starts a test FSM instance.
  """
  def start_test_fsm(opts \\ []) do
    {:ok, clock} = VirtualClock.start_link()

    test_opts = Keyword.merge([tick_interval: 10], opts)
    test_name = :"test_fsm_#{System.unique_integer([:positive])}"

    # Start FSM with virtual clock directly injected
    # Pass the options directly, not as a tuple
    case VirtualTimeGenStateMachine.start_link(
           MermaidLiveSsr.CountdownFSM,
           test_opts,
           name: test_name,
           virtual_clock: clock
         ) do
      {:ok, fsm_pid} -> {fsm_pid, clock}
      {:error, {:already_started, pid}} -> {pid, clock}
      error -> raise "Failed to start test FSM: #{inspect(error)}"
    end
  end

  @doc """
  Creates a test FSM with a specific virtual clock.

  This allows each test to have its own isolated virtual clock.
  """
  def start_test_fsm_with_clock(clock, opts \\ []) do
    test_opts = Keyword.merge([tick_interval: 10], opts)
    test_name = :"test_fsm_#{System.unique_integer([:positive])}"

    # Start FSM with virtual clock directly injected
    # Pass the options directly, not as a tuple
    case VirtualTimeGenStateMachine.start_link(
           MermaidLiveSsr.CountdownFSM,
           test_opts,
           name: test_name,
           virtual_clock: clock
         ) do
      {:ok, fsm_pid} -> {fsm_pid, clock}
      {:error, {:already_started, pid}} -> {pid, clock}
      error -> raise "Failed to start test FSM: #{inspect(error)}"
    end
  end
end
