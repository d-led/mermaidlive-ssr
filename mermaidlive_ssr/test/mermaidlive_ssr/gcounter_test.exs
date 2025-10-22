defmodule MermaidLiveSsr.GcounterTest do
  use ExUnit.Case, async: true

  alias MermaidLiveSsr.VisitorCounter

  describe "G-Counter CRDT Unit Tests" do
    setup do
      # Create unique test instances
      test_name = :"gcounter_test_#{System.unique_integer([:positive])}"
      table_name = :"test_table_#{System.unique_integer([:positive])}"
      persistence_file = "test_gcounter_#{System.unique_integer([:positive])}.dat"

      {:ok, pid} =
        VisitorCounter.start_link(
          name: test_name,
          table_name: table_name,
          persistence_file: persistence_file
        )

      %{counter: test_name, pid: pid, persistence_file: persistence_file}
    end

    test "increment increases counter", %{counter: counter} do
      assert GenServer.call(counter, :get_count) == 0

      count = GenServer.call(counter, :increment)
      assert count == 1
      assert GenServer.call(counter, :get_count) == 1
    end

    test "multiple increments work correctly", %{counter: counter} do
      GenServer.call(counter, :increment)
      GenServer.call(counter, :increment)
      GenServer.call(counter, :increment)

      assert GenServer.call(counter, :get_count) == 3
    end

    test "merge_state combines external state", %{counter: counter} do
      # Local increment
      GenServer.call(counter, :increment)
      local_count = GenServer.call(counter, :get_count)
      assert local_count == 1

      # Merge external state
      external_state = %{"node@external" => 2}
      merged_count = GenServer.call(counter, {:merge_state, external_state})

      # 1 local + 2 external
      assert merged_count == 3
      assert GenServer.call(counter, :get_count) == 3
    end

    test "merge is idempotent", %{counter: counter} do
      external_state = %{"node@external" => 1}

      # Get initial count
      initial_count = GenServer.call(counter, :get_count)

      # Merge same state multiple times
      count1 = GenServer.call(counter, {:merge_state, external_state})
      count2 = GenServer.call(counter, {:merge_state, external_state})

      assert count1 == initial_count + 1
      assert count2 == initial_count + 1
    end

    test "node identity is consistent", %{counter: counter} do
      assert GenServer.call(counter, :get_node_count) == 0

      GenServer.call(counter, :increment)
      assert GenServer.call(counter, :get_node_count) == 1
    end

    test "state persistence works", %{counter: counter, persistence_file: persistence_file} do
      GenServer.call(counter, :increment)
      GenServer.call(counter, :increment)
      assert GenServer.call(counter, :get_count) == 2

      # Manually persist
      GenServer.call(counter, :persist_state)

      # Stop and restart with new name
      GenServer.stop(counter)
      new_name = :"gcounter_test_restart_#{System.unique_integer([:positive])}"
      {:ok, _pid} = VisitorCounter.start_link(name: new_name, persistence_file: persistence_file)

      # State should be restored
      assert GenServer.call(new_name, :get_count) == 2
    end
  end
end
