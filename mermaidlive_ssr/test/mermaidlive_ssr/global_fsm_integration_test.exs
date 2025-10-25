defmodule MermaidLiveSsr.GlobalFsmIntegrationTest do
  use ExUnit.Case, async: true

  describe "FSM Integration Tests with Virtual Time" do
    setup do
      # Create a test FSM with virtual time (isolated from global FSM)
      {:ok, clock} = VirtualClock.start_link()
      test_name = :"test_fsm_#{System.unique_integer([:positive])}"
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      
      {:ok, fsm_pid} = VirtualTimeGenStateMachine.start_link(
        MermaidLiveSsr.CountdownFSM,
        [tick_interval: 100, pubsub_channel: test_channel],
        [name: test_name, virtual_clock: clock]
      )

      # Subscribe to FSM updates
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      %{fsm_pid: fsm_pid, clock: clock}
    end

    test "FSM is alive and responsive", %{fsm_pid: fsm_pid} do
      # FSM should be alive
      assert Process.alive?(fsm_pid)

      # FSM should start in waiting state
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "FSM responds to start command", %{fsm_pid: fsm_pid, clock: clock} do
      # Send start command
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # FSM should be in working state immediately
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10
    end

    test "FSM responds to abort command", %{fsm_pid: fsm_pid, clock: clock} do
      # First start the FSM
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # Verify it's working
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working

      # Send abort command
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)

      # FSM should be in aborting state
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)
    end

    test "FSM auto-transitions from aborting to waiting with virtual time", %{fsm_pid: fsm_pid, clock: clock} do
      # Start and abort the FSM
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)

      # Verify it's aborting
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting

      # Advance virtual time to trigger auto-transition back to waiting (100ms delay)
      VirtualClock.advance(clock, 100)

      # FSM should be back in waiting state
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "FSM countdown works correctly with virtual time", %{fsm_pid: fsm_pid, clock: clock} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # Check initial count
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Advance virtual time to trigger countdown (tick interval is 100ms)
      VirtualClock.advance(clock, 100)

      # Check that countdown progressed
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      count = Map.get(data, :count)
      assert count < 10
    end
  end
end
