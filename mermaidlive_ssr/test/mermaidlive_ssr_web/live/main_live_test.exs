defmodule MermaidLiveSsrWeb.MainLiveTest do
  use MermaidLiveSsrWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  describe "MainLive Integration Tests" do
    setup do
      # Start the application if not already started
      Application.ensure_all_started(:mermaidlive_ssr)

      # Subscribe to the default FSM channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, "fsm_updates")

      %{}
    end

    test "clicking start link actually starts the countdown", %{conn: conn} do
      # Create a test FSM with a known channel and name
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      test_name = :test_fsm_integration

      {:ok, test_fsm} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 100, pubsub_channel: test_channel],
          test_name
        )

      # Subscribe to the test FSM's channel (override the global subscription)
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Mount the LiveView with the test FSM by name
      {:ok, view, html} = live(conn, "/?fsm_ref=#{test_name}")

      # Verify initial state shows waiting
      assert html =~ "waiting"

      # Click the start link in the SVG
      view |> element("[phx-click=\"start\"]") |> render_click()

      # Wait for the countdown to start and assert we receive the working state message
      assert_receive {:new_state, {:working, 10}}

      # Wait for countdown to progress
      assert_receive {:new_state, {:working, count}} when count < 10, 2000

      # Clean up
      Process.exit(test_fsm, :normal)
    end

    test "clicking abort link during countdown actually aborts", %{conn: conn} do
      # Create a test FSM with a known channel and name
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      test_name = :test_fsm_abort

      {:ok, test_fsm} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 100, pubsub_channel: test_channel],
          test_name
        )

      # Subscribe to the test FSM's channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Mount the LiveView with the test FSM by name
      {:ok, view, _html} = live(conn, "/?fsm_ref=#{test_name}")

      # Click start to begin countdown
      view |> element("[phx-click=\"start\"]") |> render_click()
      assert_receive {:new_state, {:working, 10}}

      # Click abort to stop countdown
      view |> element("[phx-click=\"abort\"]") |> render_click()

      # Drain any countdown messages and wait for aborting
      # We need to loop because there might be multiple countdown ticks before abort completes
      wait_for_aborting = fn wait ->
        receive do
          {:new_state, :aborting} -> :ok
          {:new_state, {:working, _}} -> wait.(wait)
        after
          500 -> flunk("Did not receive :aborting state")
        end
      end

      wait_for_aborting.(wait_for_aborting)

      # Should auto-transition back to waiting
      assert_receive {:new_state, :waiting}, 2000

      # Clean up
      Process.exit(test_fsm, :normal)
    end

    test "clicking start multiple times is handled gracefully", %{conn: conn} do
      # Create a test FSM with a known channel and name
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      test_name = :test_fsm_multiple

      {:ok, test_fsm} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 100, pubsub_channel: test_channel],
          test_name
        )

      # Subscribe to the test FSM's channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Mount the LiveView with the test FSM by name
      {:ok, view, _html} = live(conn, "/?fsm_ref=#{test_name}")

      # Click start multiple times rapidly
      view |> element("[phx-click=\"start\"]") |> render_click()
      view |> element("[phx-click=\"start\"]") |> render_click()
      view |> element("[phx-click=\"start\"]") |> render_click()

      # Should only receive one "working 10" message (the initial start)
      assert_receive {:new_state, {:working, 10}}
      # May receive countdown ticks, but should not receive another "working 10"
      refute_receive {:new_state, {:working, 10}}, 100

      # Clean up
      Process.exit(test_fsm, :normal)
    end

    test "clicking abort when not working is handled gracefully", %{conn: conn} do
      # Create a test FSM with a known channel and name
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      test_name = :test_fsm_abort_waiting

      {:ok, test_fsm} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 100, pubsub_channel: test_channel],
          test_name
        )

      # Subscribe to the test FSM's channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Mount the LiveView with the test FSM by name
      {:ok, view, _html} = live(conn, "/?fsm_ref=#{test_name}")

      # Try to abort when in waiting state
      view |> element("[phx-click=\"abort\"]") |> render_click()

      # Should not receive any state change message
      refute_receive {:new_state, _}, 100

      # Clean up
      Process.exit(test_fsm, :normal)
    end

    test "complete countdown cycle works end-to-end", %{conn: conn} do
      # Create a test FSM with a known channel and name
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      test_name = :test_fsm_complete

      {:ok, test_fsm} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 100, pubsub_channel: test_channel],
          test_name
        )

      # Subscribe to the test FSM's channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Mount the LiveView with the test FSM by name
      {:ok, view, _html} = live(conn, "/?fsm_ref=#{test_name}")

      # Click start to begin countdown
      view |> element("[phx-click=\"start\"]") |> render_click()
      assert_receive {:new_state, {:working, 10}}

      # Wait for countdown to complete
      assert_receive {:new_state, :waiting}, 2000

      # Verify the view is back to waiting state
      html = render(view)
      assert html =~ "waiting"

      # Clean up
      Process.exit(test_fsm, :normal)
    end

    test "abort during countdown works end-to-end", %{conn: conn} do
      # Create a test FSM with a known channel and name
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"
      test_name = :test_fsm_abort_e2e

      {:ok, test_fsm} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 100, pubsub_channel: test_channel],
          test_name
        )

      # Subscribe to the test FSM's channel
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Mount the LiveView with the test FSM by name
      {:ok, view, _html} = live(conn, "/?fsm_ref=#{test_name}")

      # Click start to begin countdown
      view |> element("[phx-click=\"start\"]") |> render_click()
      assert_receive {:new_state, {:working, 10}}

      # Click abort to stop countdown
      view |> element("[phx-click=\"abort\"]") |> render_click()

      # Drain any countdown messages and wait for aborting
      # We need to loop because there might be multiple countdown ticks before abort completes
      wait_for_aborting = fn wait ->
        receive do
          {:new_state, :aborting} -> :ok
          {:new_state, {:working, _}} -> wait.(wait)
        after
          500 -> flunk("Did not receive :aborting state")
        end
      end

      wait_for_aborting.(wait_for_aborting)

      # Wait for auto-transition back to waiting
      assert_receive {:new_state, :waiting}, 2000

      # Verify the view is back to waiting state
      html = render(view)
      assert html =~ "waiting"

      # Clean up
      Process.exit(test_fsm, :normal)
    end
  end

  describe "MainLive with Custom FSM" do
    test "LiveView can use custom FSM instance", %{conn: conn} do
      # Create a custom FSM for testing with a known channel
      test_channel = "test_fsm_#{System.unique_integer([:positive])}"

      {:ok, custom_fsm} =
        MermaidLiveSsr.CountdownFSM.start_link(
          [tick_interval: 50, pubsub_channel: test_channel],
          :custom_test_fsm
        )

      # Subscribe to custom FSM messages
      Phoenix.PubSub.subscribe(MermaidLiveSsr.PubSub, test_channel)

      # Mount LiveView with custom FSM
      {:ok, view, _html} = live(conn, "/?fsm_ref=custom_test_fsm")

      # Click start link
      view |> element("[phx-click=\"start\"]") |> render_click()

      # Should receive working state from custom FSM
      assert_receive {:new_state, {:working, 10}}

      # Clean up
      Process.exit(custom_fsm, :normal)
    end
  end
end
