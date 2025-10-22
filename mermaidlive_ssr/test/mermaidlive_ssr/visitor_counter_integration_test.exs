defmodule MermaidLiveSsr.VisitorCounterIntegrationTest do
  use ExUnit.Case, async: true

  alias MermaidLiveSsr.VisitorCounter

  describe "VisitorCounter Integration with UI" do
    setup do
      # Create unique test instances
      test_name = :"integration_test_#{System.unique_integer([:positive])}"
      table_name = :"integration_table_#{System.unique_integer([:positive])}"
      persistence_file = "test_integration_#{System.unique_integer([:positive])}.dat"

      # Start a fresh counter instance
      {:ok, pid} =
        VisitorCounter.start_link(
          name: test_name,
          table_name: table_name,
          persistence_file: persistence_file
        )

      %{counter: test_name, pid: pid, persistence_file: persistence_file}
    end

    test "UI shows correct total visitors after restart", %{
      counter: counter,
      persistence_file: persistence_file
    } do
      # Get initial count
      initial_count = GenServer.call(counter, :get_count)

      # Simulate some visitors
      GenServer.call(counter, :increment)
      GenServer.call(counter, :increment)
      GenServer.call(counter, :increment)

      count_before_restart = GenServer.call(counter, :get_count)
      assert count_before_restart == initial_count + 3

      # Manually persist
      GenServer.call(counter, :persist_state)

      # Stop and restart with new name
      GenServer.stop(counter)
      new_name = :"integration_test_restart_#{System.unique_integer([:positive])}"
      {:ok, _pid} = VisitorCounter.start_link(name: new_name, persistence_file: persistence_file)

      # Check count after restart
      count_after_restart = GenServer.call(new_name, :get_count)
      assert count_after_restart == initial_count + 3
      assert count_after_restart == count_before_restart
    end

    test "UI loads correct value on startup", %{
      counter: counter,
      persistence_file: persistence_file
    } do
      # Set up some persisted state
      state = %{"nonode@nohost" => 5}
      data = :erlang.term_to_binary(state)
      File.write!(persistence_file, data)

      # Stop and restart to load the state
      GenServer.stop(counter)
      new_name = :"integration_test_load_#{System.unique_integer([:positive])}"
      {:ok, _pid} = VisitorCounter.start_link(name: new_name, persistence_file: persistence_file)

      # Check that the state was loaded
      count = GenServer.call(new_name, :get_count)
      assert count == 5
    end
  end
end
