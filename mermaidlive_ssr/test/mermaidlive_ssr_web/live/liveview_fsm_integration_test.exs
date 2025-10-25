defmodule MermaidLiveSsrWeb.Live.LiveViewFsmIntegrationTest do
  use MermaidLiveSsrWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias MermaidLiveSsrWeb.Live.FsmResolver

  describe "LiveView FSM Integration" do
    test "global FSM is accessible via supervisor" do
      # Ensure application is started
      Application.ensure_all_started(:mermaidlive_ssr)

      # Get FSM PID from supervisor
      fsm_pid = FsmResolver.get_global_fsm_pid()
      assert is_pid(fsm_pid)

      # Test that FSM is working (might be in any state due to previous tests)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state in [:waiting, :working, :aborting]

      # Test that FSM responds to commands (might be in any state initially)
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      Process.sleep(50)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)

      # FSM should be in working state after start command (unless it's aborting from previous test)
      assert state in [:working, :aborting]
    end

    test "FSM is injectable for testing with virtual time" do
      # Create a test FSM with virtual time
      {:ok, clock} = VirtualClock.start_link()

      {:ok, fsm_pid} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 100, virtual_clock: clock],
          :test_fsm
        )

      # Test that FSM works with virtual time
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Send start command
      MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working

      # Advance virtual time to trigger tick
      VirtualClock.advance(clock, 100)
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :working

      # Clean up
      GenServer.stop(fsm_pid)
      GenServer.stop(clock)
    end

    test "LiveView can be created with custom FSM for testing" do
      # Create a test FSM
      {:ok, fsm_pid} = MermaidLiveSsr.CountdownFSM.start_link([tick_interval: 100], :test_fsm)

      # Create LiveView with custom FSM
      params = %{"fsm_ref" => "test_fsm"}
      {:ok, _view, html} = live(build_conn(), "/", params)

      # Test that LiveView is working
      assert html =~ "Mermaid.js Server-Side Pre-rendered Live Demo"

      # Test that FSM is accessible
      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      assert state == :waiting

      # Clean up
      GenServer.stop(fsm_pid)
    end

    test "LiveView works with global FSM" do
      # Ensure application is started
      Application.ensure_all_started(:mermaidlive_ssr)

      # Create LiveView with default FSM
      {:ok, _view, html} = live(build_conn(), "/")

      # Test that LiveView is working
      assert html =~ "Mermaid.js Server-Side Pre-rendered Live Demo"

      # Test that we can interact with the FSM
      # This test ensures the global FSM is accessible via the supervisor
      fsm_pid = FsmResolver.get_global_fsm_pid()
      assert is_pid(fsm_pid)

      {state, _data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
      # FSM might be in any state, just ensure it's accessible
      assert state in [:waiting, :working, :aborting]
    end
  end
end
