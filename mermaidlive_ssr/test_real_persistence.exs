# Test real persistence file
IO.puts("=== Testing Real Persistence ===")

# Check current state
IO.puts("Current count: #{MermaidLiveSsr.VisitorCounter.get_count()}")

# Check if persistence file exists
if File.exists?("visitor_counter_state.dat") do
  IO.puts("Persistence file exists")
  data = File.read!("visitor_counter_state.dat")
  state = :erlang.binary_to_term(data)
  IO.puts("File contains: #{inspect(state)}")
else
  IO.puts("Persistence file does not exist")
end

# Test restart simulation
IO.puts("=== Simulating Restart ===")
GenServer.stop(MermaidLiveSsr.VisitorCounter)
IO.puts("Stopped VisitorCounter")

# Wait a moment for cleanup
Process.sleep(100)

# Start again
case MermaidLiveSsr.VisitorCounter.start_link() do
  {:ok, _pid} ->
    IO.puts("Restarted VisitorCounter")
    IO.puts("Count after restart: #{MermaidLiveSsr.VisitorCounter.get_count()}")

  {:error, {:already_started, _pid}} ->
    IO.puts("VisitorCounter already started")
    IO.puts("Count: #{MermaidLiveSsr.VisitorCounter.get_count()}")
end
