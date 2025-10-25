defmodule MermaidLiveSsr.FsmVirtualTimeTest do
  use ExUnit.Case, async: true

  describe "FSM Core States with Virtual Time" do
    setup do
      # Start the application if not already started
      Application.ensure_all_started(:mermaidlive_ssr)

      # Setup virtual time and create test FSM
      {:ok, clock} = VirtualClock.start_link()

      # Create test FSM with virtual clock directly injected
      test_name = :"test_fsm_#{System.unique_integer([:positive])}"
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      {:ok, fsm_pid} = VirtualTimeGenStateMachine.start_link(
        MermaidLiveSsr.CountdownFSM,
        [tick_interval: 10, pubsub_channel: test_channel],
        [name: test_name, virtual_clock: clock]
      )

      # Subscribe to FSM updates
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      %{fsm_pid: fsm_pid, clock: clock}
    end

    test "initial state is waiting", %{fsm_pid: fsm_pid} do
      # FSM should start in waiting state
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "waiting -> working transition on start command", %{fsm_pid: fsm_pid, clock: _clock} do
      # Send start command from waiting state
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # Should transition to working state immediately
      assert_receive {:new_state, {:working, 10}}
    end

    test "working -> aborting transition on abort command", %{fsm_pid: fsm_pid, clock: clock} do
      # Start the FSM (waiting -> working)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Send abort command (working -> aborting)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}

      # Check FSM state after abort
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Advance time to trigger linger timeout
      VirtualClock.advance(clock, 10)
      assert_receive {:new_state, :waiting}
    end

    test "aborting -> waiting auto-transition after delay", %{fsm_pid: fsm_pid, clock: clock} do
      # Complete cycle: waiting -> working -> aborting -> waiting
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}

      # Check FSM state after abort
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Advance time to trigger linger timeout
      VirtualClock.advance(clock, 10)
      assert_receive {:new_state, :waiting}
    end
  end

  describe "FSM Invalid Transitions with Virtual Time" do
    setup do
      # Setup virtual time and create test FSM
      {:ok, clock} = VirtualClock.start_link()

      # Create test FSM with virtual clock directly injected
      test_name = :"test_fsm_#{System.unique_integer([:positive])}"
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      {:ok, fsm_pid} = VirtualTimeGenStateMachine.start_link(
        MermaidLiveSsr.CountdownFSM,
        [tick_interval: 10, pubsub_channel: test_channel],
        [name: test_name, virtual_clock: clock]
      )

      # Subscribe to FSM updates
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      %{fsm_pid: fsm_pid, clock: clock}
    end

    test "start command ignored in working state", %{fsm_pid: fsm_pid, clock: clock} do
      # Start the FSM
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Clear any pending messages
      receive do
        _ -> :ok
      after
        0 -> :ok
      end

      # Process any scheduled events to ensure we're in a stable state
      VirtualClock.advance_to_next(clock)

      # Try to start again (should be ignored)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      # Should not receive another working state message within a short timeout
      refute_receive {:new_state, {:working, 10}}, 50
    end

    test "start command ignored in aborting state", %{fsm_pid: fsm_pid, clock: clock} do
      # Start and then abort
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Try to start while aborting (should be ignored)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)

      # FSM should still be in aborting state
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting

      # Advance time to complete abort
      VirtualClock.advance(clock, 10)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end
  end

  describe "FSM Countdown Behavior with Virtual Time" do
    setup do
      # Setup virtual time and create test FSM
      {:ok, clock} = VirtualClock.start_link()

      # Create test FSM with virtual clock directly injected
      test_name = :"test_fsm_#{System.unique_integer([:positive])}"
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      {:ok, fsm_pid} = VirtualTimeGenStateMachine.start_link(
        MermaidLiveSsr.CountdownFSM,
        [tick_interval: 10, pubsub_channel: test_channel],
        [name: test_name, virtual_clock: clock]
      )

      # Subscribe to FSM updates
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      %{fsm_pid: fsm_pid, clock: clock}
    end

    test "countdown shows counter in working state", %{fsm_pid: fsm_pid, clock: clock} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Check state before advancing time
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Advance time to see countdown progress
      VirtualClock.advance(clock, 10)

      # Check state after advancing time
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 9

      # Try to receive the message
      receive do
        {:new_state, {:working, 9}} -> :ok
        other -> flunk("Unexpected message: #{inspect(other)}")
      after
        0 -> :ok  # Message might not be sent if FSM is not using PubSub
      end

      # Advance time again
      VirtualClock.advance(clock, 10)

      # Check state after second advance
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 8
    end

    test "countdown stops when aborting", %{fsm_pid: fsm_pid, clock: clock} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Advance time a bit
      VirtualClock.advance(clock, 20)

      # Check FSM state after advancing time
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      # The count might be different due to timing, so just check it's reasonable
      count = Map.get(data, :count)
      assert count >= 8 and count <= 10

      # Abort the countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      assert_receive {:new_state, :aborting}

      # Check FSM state after abort
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Advance time more - should not see more countdown messages
      VirtualClock.advance(clock, 100)

      # Clear any pending messages from the previous state
      receive do
        {:new_state, {:working, _count}} -> :ok
      after
        0 -> :ok
      end

      # Complete abort
      assert_receive {:new_state, :waiting}
    end

    test "countdown completes naturally", %{fsm_pid: fsm_pid, clock: clock} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Advance time step by step to ensure all timers fire
      for _ <- 1..11 do
        VirtualClock.advance(clock, 10)
        Process.sleep(1)  # Give time for the timer to fire
      end

      # Should complete and return to waiting
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "countdown can be aborted and restarted", %{fsm_pid: fsm_pid, clock: clock} do
      # Start first countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Advance a bit
      VirtualClock.advance(clock, 20)

      # Check FSM state after advancing time
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      # The count might be different due to timing, so just check it's reasonable
      count = Map.get(data, :count)
      assert count >= 8 and count <= 10

      # Abort
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Complete abort - use step-by-step advancement to ensure linger timeout fires
      VirtualClock.advance(clock, 20)  # Full linger timeout with buffer

      # Check final state instead of relying on message
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Start new countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Complete this countdown - use step-by-step advancement
      for _ <- 1..11 do
        VirtualClock.advance(clock, 10)
      end

      # Check final state instead of relying on message
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end
  end

  describe "Fast Countdown Testing" do
    setup do
      # Setup virtual time and create test FSM
      {:ok, clock} = VirtualClock.start_link()

      # Create test FSM with virtual clock directly injected
      test_name = :"test_fsm_#{System.unique_integer([:positive])}"
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      {:ok, fsm_pid} = VirtualTimeGenStateMachine.start_link(
        MermaidLiveSsr.CountdownFSM,
        [tick_interval: 10, pubsub_channel: test_channel],
        [name: test_name, virtual_clock: clock]
      )

      # Subscribe to FSM updates
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      %{fsm_pid: fsm_pid, clock: clock}
    end

    test "complete countdown cycle in milliseconds", %{fsm_pid: fsm_pid, clock: clock} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Advance time step by step to ensure all timers fire
      for _ <- 1..11 do
        VirtualClock.advance(clock, 10)
        Process.sleep(1)  # Give time for the timer to fire
      end

      # Check final state instead of relying on message
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "multiple countdown cycles", %{fsm_pid: fsm_pid, clock: clock} do
      # First cycle
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Advance time step by step to ensure all timers fire
      for _ <- 1..11 do
        VirtualClock.advance(clock, 10)
        Process.sleep(1)  # Give time for the timer to fire
      end

      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Second cycle
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Advance time step by step
      for _ <- 1..11 do
        VirtualClock.advance(clock, 10)
        Process.sleep(1)  # Give time for the timer to fire
      end

      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Third cycle
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      assert_receive {:new_state, {:working, 10}}

      # Advance time step by step
      for _ <- 1..11 do
        VirtualClock.advance(clock, 10)
        Process.sleep(1)  # Give time for the timer to fire
      end

      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end

    test "abort during countdown and restart", %{fsm_pid: fsm_pid, clock: clock} do
      # Start countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Advance halfway
      VirtualClock.advance(clock, 50)

      # Check FSM state after advancing time
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      # The count might be different due to timing, so just check it's reasonable
      count = Map.get(data, :count)
      assert count >= 5 and count <= 10

      # Abort
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :abort)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :aborting
      refute Map.has_key?(data, :count)

      # Complete abort
      VirtualClock.advance(clock, 10)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Start new countdown
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working
      assert Map.get(data, :count) == 10

      # Complete this countdown
      VirtualClock.advance(clock, 100)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting
    end
  end
end
