defmodule MermaidLiveSsr.VisitorCounterTest do
  use ExUnit.Case, async: true

  alias MermaidLiveSsr.VisitorCounter

  describe "VisitorCounter Unit Tests" do
    setup do
      # Create a unique test counter instance
      test_name = :"test_counter_#{System.unique_integer([:positive])}"
      table_name = :"test_table_#{System.unique_integer([:positive])}"
      persistence_file = "test_visitor_counter_#{System.unique_integer([:positive])}.dat"

      # Start a fresh counter instance
      {:ok, pid} =
        VisitorCounter.start_link(
          name: test_name,
          table_name: table_name,
          persistence_file: persistence_file
        )

      # Set up cleanup
      on_exit(fn ->
        cleanup_counter(%{pid: pid, table_name: table_name, persistence_file: persistence_file})
      end)

      # Return the test counter module and cleanup info
      %{
        counter: test_name,
        pid: pid,
        table_name: table_name,
        persistence_file: persistence_file
      }
    end

    # Cleanup function to stop the counter and clean up ETS tables
    defp cleanup_counter(%{pid: pid, table_name: table_name, persistence_file: persistence_file}) do
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end

      # Clean up ETS table
      try do
        :ets.delete(table_name)
      rescue
        _ -> :ok
      end

      # Clean up persistence file
      try do
        File.rm(persistence_file)
      rescue
        _ -> :ok
      end

      # Note: We don't clean up the global :visitor_counter table as it's used by Presence
      # and other parts of the application. The test-specific table is cleaned up above.
    end

    test "counter starts with zero count", %{counter: counter} do
      count = GenServer.call(counter, :get_count)
      assert count == 0
    end

    test "increment increases the counter", %{counter: counter} do
      initial_count = GenServer.call(counter, :get_count)
      new_count = GenServer.call(counter, :increment)

      assert new_count == initial_count + 1
      assert GenServer.call(counter, :get_count) == new_count
    end

    test "multiple increments work correctly", %{counter: counter} do
      # Increment multiple times
      count1 = GenServer.call(counter, :increment)
      count2 = GenServer.call(counter, :increment)
      count3 = GenServer.call(counter, :increment)

      assert count1 == 1
      assert count2 == 2
      assert count3 == 3
      assert GenServer.call(counter, :get_count) == 3
    end

    test "get_node_count returns current node's contribution", %{counter: counter} do
      # Initially, node count should be 0
      assert GenServer.call(counter, :get_node_count) == 0

      # After incrementing, node count should be 1
      GenServer.call(counter, :increment)
      assert GenServer.call(counter, :get_node_count) == 1

      # After another increment, node count should be 2
      GenServer.call(counter, :increment)
      assert GenServer.call(counter, :get_node_count) == 2
    end

    test "counter state can be retrieved", %{counter: counter} do
      # Get initial state
      initial_state = GenServer.call(counter, :get_state)
      assert is_map(initial_state)

      # Increment and get new state
      GenServer.call(counter, :increment)
      new_state = GenServer.call(counter, :get_state)

      # State should be different
      assert new_state != initial_state
    end

    test "counter handles rapid increments", %{counter: counter} do
      # Get initial count
      initial_count = GenServer.call(counter, :get_count)

      # Send multiple increments rapidly
      tasks =
        for _i <- 1..10 do
          Task.async(fn -> GenServer.call(counter, :increment) end)
        end

      results = Task.await_many(tasks, 5000)

      # All increments should succeed
      assert length(results) == 10
      assert GenServer.call(counter, :get_count) == initial_count + 10
    end
  end

  describe "VisitorCounter Persistence Tests" do
    setup do
      # Create a unique test counter instance
      test_name = :"test_counter_#{System.unique_integer([:positive])}"
      persistence_file = "test_visitor_counter_#{System.unique_integer([:positive])}.dat"
      table_name = :"test_table_#{System.unique_integer([:positive])}"

      # Clean up any existing persistence file
      File.rm(persistence_file)

      # Start a fresh counter instance
      {:ok, pid} =
        VisitorCounter.start_link(
          name: test_name,
          table_name: table_name,
          persistence_file: persistence_file
        )

      # Set up cleanup
      on_exit(fn ->
        # Clean up the persistence file
        File.rm(persistence_file)

        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      # Return the test counter module and cleanup info
      %{
        counter: test_name,
        pid: pid,
        persistence_file: persistence_file,
        table_name: table_name
      }
    end

    test "counter state persists across restarts", %{
      counter: counter,
      persistence_file: persistence_file
    } do
      # Increment the counter
      GenServer.call(counter, :increment)
      GenServer.call(counter, :increment)
      assert GenServer.call(counter, :get_count) == 2

      # Manually trigger persistence
      GenServer.call(counter, :persist_state)

      # Stop the counter process
      GenServer.stop(counter)

      # Start it again with the same persistence file
      {:ok, new_pid} =
        VisitorCounter.start_link(name: counter, persistence_file: persistence_file)

      # State should be restored
      assert GenServer.call(new_pid, :get_count) == 2

      # Clean up the new process
      GenServer.stop(new_pid)
    end

    test "counter handles missing persistence file gracefully", %{
      counter: counter,
      persistence_file: persistence_file
    } do
      # Remove persistence file if it exists
      File.rm(persistence_file)

      # Stop and restart the counter
      GenServer.stop(counter)
      {:ok, _pid} = VisitorCounter.start_link(name: counter, persistence_file: persistence_file)

      # Should start with zero count
      assert GenServer.call(counter, :get_count) == 0
    end
  end

  describe "VisitorCounter CRDT Merge Tests" do
    setup do
      # Create a unique test counter instance
      test_name = :"test_counter_#{System.unique_integer([:positive])}"
      table_name = :"test_table_#{System.unique_integer([:positive])}"
      persistence_file = "test_visitor_counter_#{System.unique_integer([:positive])}.dat"

      # Start a fresh counter instance
      {:ok, pid} =
        VisitorCounter.start_link(
          name: test_name,
          table_name: table_name,
          persistence_file: persistence_file
        )

      # Set up cleanup
      on_exit(fn ->
        cleanup_counter(%{pid: pid, table_name: table_name, persistence_file: persistence_file})
      end)

      # Return the test counter module and cleanup info
      %{
        counter: test_name,
        pid: pid,
        table_name: table_name,
        persistence_file: persistence_file
      }
    end

    test "merge_state combines external state correctly", %{counter: counter} do
      # Create a mock external state (simulating another node)
      external_state = %{"node@external" => 2}

      # Increment local counter
      GenServer.call(counter, :increment)
      local_count = GenServer.call(counter, :get_count)
      assert local_count == 1

      # Merge external state
      merged_count = GenServer.call(counter, {:merge_state, external_state})

      # Total count should be 3 (1 local + 2 external)
      assert merged_count == 3
      assert GenServer.call(counter, :get_count) == 3
    end

    test "merge_state is idempotent", %{counter: counter} do
      # Create external state
      external_state = %{"node@external" => 1}

      # Get initial count
      initial_count = GenServer.call(counter, :get_count)

      # Merge the same state multiple times
      count1 = GenServer.call(counter, {:merge_state, external_state})
      count2 = GenServer.call(counter, {:merge_state, external_state})
      count3 = GenServer.call(counter, {:merge_state, external_state})

      # Count should not increase with duplicate merges
      # Each merge should only add the external count (1) the first time
      assert count1 == initial_count + 1
      assert count2 == initial_count + 1
      assert count3 == initial_count + 1
    end

    test "merge_state handles empty external state", %{counter: counter} do
      empty_state = %{}

      # Increment local counter first
      GenServer.call(counter, :increment)
      initial_count = GenServer.call(counter, :get_count)

      # Merge empty state
      merged_count = GenServer.call(counter, {:merge_state, empty_state})

      # Count should remain the same
      assert merged_count == initial_count
    end
  end

  describe "VisitorCounter ETS Integration Tests" do
    setup do
      # Create a unique test counter instance
      test_name = :"test_counter_#{System.unique_integer([:positive])}"
      table_name = :"test_table_#{System.unique_integer([:positive])}"
      persistence_file = "test_visitor_counter_#{System.unique_integer([:positive])}.dat"

      # Start a fresh counter instance
      {:ok, pid} =
        VisitorCounter.start_link(
          name: test_name,
          table_name: table_name,
          persistence_file: persistence_file
        )

      # Return the test counter module and cleanup info
      %{
        counter: test_name,
        pid: pid,
        table_name: table_name,
        persistence_file: persistence_file
      }
    end

    test "counter state is stored in ETS table", %{counter: counter, table_name: table_name} do
      # Check that ETS table exists
      assert :ets.whereis(table_name) != :undefined

      # Increment counter
      GenServer.call(counter, :increment)

      # Check that state is stored in ETS
      [{:counter_state, state}] = :ets.lookup(table_name, :counter_state)
      assert is_map(state)
    end

    test "ETS table is accessible from other processes", %{
      counter: counter,
      table_name: table_name
    } do
      # Increment counter
      GenServer.call(counter, :increment)

      # Access ETS table from another process
      task =
        Task.async(fn ->
          case :ets.lookup(table_name, :counter_state) do
            [{:counter_state, state}] -> state
            [] -> nil
          end
        end)

      state = Task.await(task)
      assert is_map(state)
    end
  end

  describe "VisitorCounter Node Identity Tests" do
    setup do
      # Create a unique test counter instance
      test_name = :"test_counter_#{System.unique_integer([:positive])}"
      persistence_file = "test_visitor_counter_#{System.unique_integer([:positive])}.dat"

      # Start a fresh counter instance
      {:ok, pid} =
        VisitorCounter.start_link(
          name: test_name,
          table_name: :"test_table_#{System.unique_integer([:positive])}",
          persistence_file: persistence_file
        )

      # Return the test counter module and cleanup info
      %{
        counter: test_name,
        pid: pid,
        persistence_file: persistence_file
      }
    end

    test "node identity is consistent", %{counter: counter} do
      # Get node identity multiple times
      identity1 = GenServer.call(counter, :get_node_count)
      identity2 = GenServer.call(counter, :get_node_count)

      # Should be consistent
      assert identity1 == identity2
    end

    test "node identity is used for increments", %{counter: counter} do
      # Get initial node count (may be > 0 from other tests on same node)
      initial_node_count = GenServer.call(counter, :get_node_count)

      # Increment counter
      GenServer.call(counter, :increment)

      # Node count should increase by 1
      assert GenServer.call(counter, :get_node_count) == initial_node_count + 1

      # Total count should also increase by 1
      assert GenServer.call(counter, :get_count) == initial_node_count + 1
    end
  end
end
