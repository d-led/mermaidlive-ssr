defmodule MermaidLiveSsr.FsmInjectabilityTest do
  use ExUnit.Case, async: true

  describe "FSM Injectability for Testing" do
    test "FSM can be injected with virtual time for testing" do
      # This test verifies that we can create a test FSM with virtual time
      # that can be used in LiveView tests

      # Create a test FSM with virtual time
      {:ok, clock} = VirtualClock.start_link()
      test_name = :"test_fsm_#{System.unique_integer([:positive])}"
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"

      # Create a test FSM with virtual clock injected at start_link time
      {:ok, fsm_pid} = VirtualTimeGenStateMachine.start_link(
        MermaidLiveSsr.CountdownFSM,
        [tick_interval: 10, pubsub_channel: test_channel],
        [name: test_name, virtual_clock: clock]
      )

      # Test that the FSM works with virtual time
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Start the FSM
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Advance virtual time to trigger countdown
      VirtualClock.advance(clock, 10)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 9

      # Test abort
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Advance time to complete abort
      VirtualClock.advance(clock, 10)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Clean up
      GenServer.stop(fsm_pid)
      GenServer.stop(clock)
    end

    test "FSM can be injected with real time for testing" do
      # This test verifies that we can create a test FSM with real time
      # that can be used in LiveView tests

      # Create a test FSM with real time
      test_name = :"test_fsm_#{System.unique_integer([:positive])}"
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"

      # Create a test FSM without virtual clock (uses real time)
      {:ok, fsm_pid} = VirtualTimeGenStateMachine.start_link(
        MermaidLiveSsr.CountdownFSM,
        [tick_interval: 50, pubsub_channel: test_channel],
        [name: test_name]
      )

      # Test that the FSM works with real time
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Start the FSM
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Wait for real time countdown
      Process.sleep(100)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      count = Map.get(data, :count)
      assert count < 10

      # Test abort
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Wait for real time abort completion
      Process.sleep(100)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Clean up
      GenServer.stop(fsm_pid)
    end
  end
end
