#!/usr/bin/env elixir

# Debug script to check FSM by PID
Application.ensure_all_started(:mermaidlive_ssr)

IO.puts("Checking FSM by PID...")

children = Supervisor.which_children(MermaidLiveSsr.Supervisor)
fsm_child = Enum.find(children, fn {id, _, _, _} -> id == MermaidLiveSsr.CountdownFSM end)

if fsm_child do
  {_id, pid, _type, _modules} = fsm_child
  IO.puts("FSM PID: #{inspect(pid)}")
  IO.puts("Alive: #{Process.alive?(pid)}")

  if Process.alive?(pid) do
    # Try to get state directly from the PID
    try do
      {state, data} = MermaidLiveSsr.CountdownFSM.get_state(pid)
      IO.puts("State: #{state}")
      IO.puts("Data: #{inspect(data)}")
    rescue
      error -> IO.puts("Error getting state: #{inspect(error)}")
    end
  else
    IO.puts("FSM process is not alive!")
  end
else
  IO.puts("FSM not found in supervisor!")
end
