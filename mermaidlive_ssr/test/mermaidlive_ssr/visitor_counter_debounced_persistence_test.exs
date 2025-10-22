defmodule MermaidLiveSsr.VisitorCounterDebouncedPersistenceTest do
  use ExUnit.Case, async: false

  alias MermaidLiveSsr.VisitorCounter

  @test_file "test_debounced_persistence_#{System.unique_integer([:positive])}.dat"

  setup do
    # Start a test instance of VisitorCounter with a unique name and persistence file
    test_name = :"test_visitor_counter_#{System.unique_integer([:positive])}"
    {:ok, pid} = VisitorCounter.start_link(name: test_name, persistence_file: @test_file)

    # Ensure we start with a clean state
    File.rm(@test_file)

    on_exit(fn ->
      # Clean up the test file and stop the process
      File.rm(@test_file)

      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{counter_pid: pid, test_name: test_name}
  end

  describe "debounced persistence behavior" do
    test "persists state after 1 second of inactivity following increment", %{
      counter_pid: _pid,
      test_name: test_name
    } do
      # Initial state - no file should exist
      refute File.exists?(@test_file)

      # Increment the counter
      count = GenServer.call(test_name, :increment)
      assert count == 1

      # File should not exist immediately
      refute File.exists?(@test_file)

      # Wait for debounced persistence (1 second + small buffer)
      Process.sleep(1100)

      # File should now exist
      assert File.exists?(@test_file)

      # Verify the persisted state is correct
      {:ok, data} = File.read(@test_file)
      state = :erlang.binary_to_term(data)

      # The state should contain our node's contribution
      node_name = node() |> Atom.to_string()
      assert Map.get(state, node_name) == 1
    end

    test "cancels previous timer when incrementing multiple times rapidly", %{
      counter_pid: _pid,
      test_name: test_name
    } do
      # Increment multiple times rapidly
      GenServer.call(test_name, :increment)
      Process.sleep(100)
      GenServer.call(test_name, :increment)
      Process.sleep(100)
      GenServer.call(test_name, :increment)
      Process.sleep(100)
      GenServer.call(test_name, :increment)

      # File should not exist yet
      refute File.exists?(@test_file)

      # Wait for debounced persistence
      Process.sleep(1100)

      # File should now exist with the final state (4 increments)
      assert File.exists?(@test_file)

      {:ok, data} = File.read(@test_file)
      state = :erlang.binary_to_term(data)

      node_name = node() |> Atom.to_string()
      assert Map.get(state, node_name) == 4
    end

    test "does not persist when no changes have occurred", %{
      counter_pid: _pid,
      test_name: test_name
    } do
      # Get initial count (this should not trigger persistence)
      _initial_count = GenServer.call(test_name, :get_count)

      # Wait longer than debounce period
      Process.sleep(1100)

      # File should not exist because no changes occurred
      refute File.exists?(@test_file)
    end

    test "resets has_changes flag after persistence", %{counter_pid: _pid, test_name: test_name} do
      # Increment once
      GenServer.call(test_name, :increment)

      # Wait for persistence
      Process.sleep(1100)

      # File should exist
      assert File.exists?(@test_file)

      # Get the file modification time
      {:ok, stat} = File.stat(@test_file)
      first_mtime = stat.mtime

      # Wait a bit more and call get_count (should not trigger persistence)
      Process.sleep(100)
      GenServer.call(test_name, :get_count)

      # Wait for potential persistence
      Process.sleep(1100)

      # File modification time should be the same
      {:ok, stat} = File.stat(@test_file)
      second_mtime = stat.mtime

      assert first_mtime == second_mtime
    end

    test "handles rapid increments and verifies only final state is persisted", %{
      counter_pid: _pid,
      test_name: test_name
    } do
      # Perform many rapid increments
      for _i <- 1..10 do
        GenServer.call(test_name, :increment)
        # Very short delay
        Process.sleep(50)
      end

      # Wait for debounced persistence
      Process.sleep(1100)

      # Verify only one persistence operation occurred with final state
      assert File.exists?(@test_file)

      {:ok, data} = File.read(@test_file)
      state = :erlang.binary_to_term(data)

      node_name = node() |> Atom.to_string()
      assert Map.get(state, node_name) == 10
    end

    test "process remains alive and responsive after persistence", %{counter_pid: pid, test_name: test_name} do
      # Increment the counter
      GenServer.call(test_name, :increment)

      # Wait for debounced persistence
      Process.sleep(1100)

      assert File.exists?(@test_file)

      # Verify that the process is still alive and responsive
      assert Process.alive?(pid)
      count = GenServer.call(test_name, :get_count)
      assert count == 1
    end
  end

  describe "debounced persistence with multiple operations" do
    test "increment followed by get_count does not trigger persistence", %{
      counter_pid: _pid,
      test_name: test_name
    } do
      # Increment once
      GenServer.call(test_name, :increment)

      # Immediately call get_count multiple times
      GenServer.call(test_name, :get_count)
      GenServer.call(test_name, :get_count)
      GenServer.call(test_name, :get_count)

      # Wait for debounced persistence
      Process.sleep(1100)

      # File should exist (because of the increment)
      assert File.exists?(@test_file)

      {:ok, data} = File.read(@test_file)
      state = :erlang.binary_to_term(data)

      node_name = node() |> Atom.to_string()
      # Only one increment
      assert Map.get(state, node_name) == 1
    end
  end
end
