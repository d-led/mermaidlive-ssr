defmodule MermaidLiveSsr.CountdownFSMTest do
  use ExUnit.Case, async: true

  describe "CountdownFSM Unit Tests" do
    setup do
      # Start the application if not already started
      Application.ensure_all_started(:mermaidlive_ssr)

      # Create an isolated FSM for testing with a known channel
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"

      {:ok, fsm_pid} =
        case MermaidLiveSsr.CountdownFSM.start_link(
               [tick_interval: 10, pubsub_channel: test_channel],
               :test_fsm
             ) do
          {:error, {:already_started, pid}} -> {:ok, pid}
          result -> result
        end

      # Subscribe to the FSM's specific channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      %{fsm_pid: fsm_pid}
    end

    test "FSM starts in waiting state", %{fsm_pid: fsm_pid} do
      # FSM should be alive
      assert Process.alive?(fsm_pid)

      # Should be able to start work
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}
    end

    test "FSM transitions from waiting to working on start command", %{fsm_pid: fsm_pid} do
      # Send start command
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}
    end

    test "FSM transitions from working to aborting on abort command", %{fsm_pid: fsm_pid} do
      # First get to working state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Send abort command
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}
    end

    test "FSM auto-transitions from aborting to waiting", %{fsm_pid: fsm_pid} do
      # Get to aborting state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}

      # Wait for auto-transition back to waiting
      assert_receive {:new_state, :waiting}, 2000
    end

    test "FSM countdown behavior - starts at 10 and decrements", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Wait for countdown to progress
      assert_receive {:new_state, {:working, count}} when count < 10, 2000
    end

    test "FSM completes full countdown cycle", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Wait for completion
      assert_receive {:new_state, :waiting}, 2000
    end

    test "FSM ignores abort command when in waiting state", %{fsm_pid: fsm_pid} do
      # Try to abort while in waiting state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)

      # Should receive error message
      assert_receive {:fsm_error, "Cannot abort while in :waiting state"}

      # Should not receive any state change message
      refute_receive {:new_state, _}, 100

      # FSM should still be alive
      assert Process.alive?(fsm_pid)
    end

    test "FSM ignores start command when already working", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Try to start again while already working
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # Should receive error message for invalid start command
      assert_receive {:fsm_error, "Cannot start while in :working state"}

      # FSM should continue its normal countdown (not restart)
      # We should receive the next countdown state, not a restart to 10
      assert_receive {:new_state, {:working, 9}}, 200

      # FSM should still be alive
      assert Process.alive?(fsm_pid)
    end

    test "FSM can be aborted during countdown", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Abort during countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}

      # Should auto-transition back to waiting
      assert_receive {:new_state, :waiting}, 2000
    end

    test "FSM handles multiple rapid commands gracefully", %{fsm_pid: fsm_pid} do
      # Send multiple start commands rapidly
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # Should receive one working state message
      assert_receive {:new_state, {:working, 10}}

      # Should receive error messages for the invalid start commands
      assert_receive {:fsm_error, "Cannot start while in :working state"}
      assert_receive {:fsm_error, "Cannot start while in :working state"}

      # FSM should still be alive
      assert Process.alive?(fsm_pid)
    end

    test "FSM handles rapid start/abort commands", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Send multiple abort commands rapidly
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)

      # Should only receive one aborting state message
      assert_receive {:new_state, :aborting}

      # Should not receive duplicate aborting messages
      refute_receive {:new_state, :aborting}, 50

      # Should auto-transition back to waiting
      assert_receive {:new_state, :waiting}, 2000
    end

    test "FSM handles invalid start command in aborting state", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Abort to get to aborting state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}

      # Try to start while in aborting state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # Should receive error message for invalid start command
      assert_receive {:fsm_error, "Cannot start while in :aborting state"}

      # FSM should still be alive and eventually transition to waiting
      assert Process.alive?(fsm_pid)
    end

    test "FSM handles invalid abort command in aborting state", %{fsm_pid: fsm_pid} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Abort to get to aborting state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}

      # Try to abort again while in aborting state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)

      # Should receive error message for invalid abort command
      assert_receive {:fsm_error, "Cannot abort while in :aborting state"}

      # FSM should still be alive and eventually transition to waiting
      assert Process.alive?(fsm_pid)
    end
  end

  describe "CountdownFSM Configuration Tests" do
    test "FSM uses custom tick interval" do
      # Create FSM with custom tick interval and known channel
      test_channel = "test_custom_fsm_#{System.unique_integer([:positive])}"

      {:ok, fsm_pid} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 10, pubsub_channel: test_channel],
          :test_custom_fsm
        )

      # Subscribe to the FSM's specific channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # With 50ms tick interval, should see countdown progress faster
      assert_receive {:new_state, {:working, count}} when count < 10, 1000

      # Clean up
      Process.exit(fsm_pid, :normal)
    end

    test "FSM uses custom pubsub channel" do
      # Create FSM with custom pubsub channel
      {:ok, fsm_pid} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [pubsub_channel: "custom_channel"],
          :test_custom_channel_fsm
        )

      # Subscribe to custom channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "custom_channel")

      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Clean up
      Process.exit(fsm_pid, :normal)
    end
  end
end
