#!/usr/bin/env elixir

# Test FSM directly by PID
Application.ensure_all_started(:mermaidlive_ssr)

IO.puts("Testing FSM directly...")

children = Supervisor.which_children(MermaidLiveSsr.Supervisor)
fsm_child = Enum.find(children, fn {id, _, _, _} -> id == MermaidLiveSsr.CountdownFSM end)

if fsm_child do
  {_id, pid, _type, _modules} = fsm_child
  IO.puts("FSM PID: #{inspect(pid)}")

  # Test the FSM
  {state, data} = MermaidLiveSsr.CountdownFSM.get_state(pid)
  IO.puts("Initial State: #{state}")
  IO.puts("Initial Data: #{inspect(data)}")

  # Test sending a command
  IO.puts("Sending start command...")
  MermaidLiveSsr.CountdownFSM.send_command(pid, :start)
  Process.sleep(100)

  {state, data} = MermaidLiveSsr.CountdownFSM.get_state(pid)
  IO.puts("After start - State: #{state}")
  IO.puts("After start - Data: #{inspect(data)}")

  # Test abort
  IO.puts("Sending abort command...")
  MermaidLiveSsr.CountdownFSM.send_command(pid, :abort)
  Process.sleep(100)

  {state, data} = MermaidLiveSsr.CountdownFSM.get_state(pid)
  IO.puts("After abort - State: #{state}")
  IO.puts("After abort - Data: #{inspect(data)}")
else
  IO.puts("FSM not found in supervisor!")
end
