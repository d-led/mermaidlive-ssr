defmodule MermaidLiveSsr.GlobalFsmIntegrationTest do
  use ExUnit.Case, async: false  # Not async to avoid conflicts with global FSM

  describe "Global FSM Integration Tests" do
    setup do
      # Start the application if not already started
      Application.ensure_all_started(:mermaidlive_ssr)

      # Get the global FSM PID
      fsm_pid = Process.whereis(MermaidLiveSsr.CountdownFSM)

      if fsm_pid do
        # Reset FSM to waiting state if it's in a different state
        case MermaidLiveSsr.CountdownFSM.get_state(fsm_pid) do
          {:aborting, _} ->
            # Wait for auto-transition from aborting to waiting
            receive do
              {:new_state, :waiting} -> :ok
            after
              2000 -> :ok  # Timeout after 2 seconds
            end
          _ ->
            :ok
        end
      end

      %{fsm_pid: fsm_pid}
    end

    test "global FSM is alive and responsive", %{fsm_pid: fsm_pid} do
      # FSM should be alive
      assert Process.alive?(fsm_pid)

      # FSM should start in waiting state
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "global FSM responds to start command", %{fsm_pid: fsm_pid} do
      # Send start command
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # Wait a bit for state transition
      Process.sleep(100)

      # FSM should be in working state
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10
    end

    test "global FSM responds to abort command", %{fsm_pid: fsm_pid} do
      # First start the FSM
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      Process.sleep(100)

      # Verify it's working
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working

      # Send abort command
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      Process.sleep(100)

      # FSM should be in aborting state
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)
    end

    test "global FSM auto-transitions from aborting to waiting", %{fsm_pid: fsm_pid} do
      # Start and abort the FSM
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      Process.sleep(100)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      Process.sleep(100)

      # Wait for auto-transition back to waiting (1 second delay)
      Process.sleep(1200)

      # FSM should be back in waiting state
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "global FSM countdown works correctly", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      Process.sleep(100)

      # Check initial count
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Wait for countdown to progress
      Process.sleep(200)

      # Check that countdown progressed
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      count = Map.get(data, :count)
      assert count < 10
    end
  end
end
