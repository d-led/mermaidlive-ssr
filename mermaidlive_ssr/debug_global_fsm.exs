#!/usr/bin/env elixir

# Debug script to check global FSM
Application.ensure_all_started(:mermaidlive_ssr)

IO.puts("Checking global FSM...")

fsm_pid = Process.whereis(MermaidLiveSsr.CountdownFSM)
IO.puts("FSM PID: #{inspect(fsm_pid)}")

if fsm_pid do
  IO.puts("Alive: #{Process.alive?(fsm_pid)}")

  {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
  IO.puts("State: #{state}")
  IO.puts("Data: #{inspect(data)}")

  # Test sending a command
  IO.puts("Sending start command...")
  MermaidLiveSsr.CountdownFSM.send_command(fsm_pid, :start)
  Process.sleep(100)

  {state, data} = MermaidLiveSsr.CountdownFSM.get_state(fsm_pid)
  IO.puts("After start - State: #{state}")
  IO.puts("After start - Data: #{inspect(data)}")
else
  IO.puts("FSM is not started!")
end
