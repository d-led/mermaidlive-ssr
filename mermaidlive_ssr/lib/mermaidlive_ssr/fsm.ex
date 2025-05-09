defmodule MermaidLiveSsr.FSM do
  @behaviour :gen_statem

  @fsm_updates_channel "fsm_updates"

  # Public API
  def start_link(_) do
    :gen_statem.start_link(__MODULE__, [], name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(_) do
    schedule_demo_start(self())
    {:ok, :waiting, nil}
  end

  # inform the supervisor about the child spec
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  @impl true
  def callback_mode, do: :state_functions

  # State: Waiting
  def waiting(:cast, :start, _data) do
    publish_state_change({:working, 10})
    {:next_state, :working, 10, {:state_timeout, 1_000, :tick}}
  end

  def waiting(:cast, :abort, _data) do
    publish_fsm_error("Cannot abort while in :waiting state")
    {:keep_state_and_data, {:reply, :error}}
  end

  def waiting(_event, _content, _data) do
    {:keep_state_and_data, {:reply, :error}}
  end

  # State: Working
  def working(:state_timeout, :tick, 1) do
    # when finished
    schedule_demo_start(self())
    publish_state_change(:waiting)
    {:next_state, :waiting, nil}
  end

  def working(:state_timeout, :tick, count) when count > 1 do
    publish_state_change({:working, count-1})
    {:keep_state, count - 1, {:state_timeout, 1_000, :tick}}
  end

  def working(:cast, :abort, _data) do
    publish_state_change(:aborting)
    {:next_state, :aborting, nil, {:state_timeout, 1_000, :linger}}
  end

  def working(_event, _content, _data) do
    {:keep_state_and_data, {:reply, :error}}
  end

  # State: Aborting
  def aborting(:state_timeout, :linger, _data) do
    publish_state_change(:waiting)
    {:next_state, :waiting, nil}
  end

  def aborting(_event, _content, _data) do
    {:keep_state_and_data, {:reply, :error}}
  end

  defp schedule_demo_start(fsm) do
    Task.start(fn ->
      Process.sleep(3_000)
      :gen_statem.cast(fsm, :start)
    end)
  end

  defp publish_state_change(new_state) do
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      @fsm_updates_channel,
      {:new_state, new_state}
    )
  end

  defp publish_fsm_error(error) do
    Phoenix.PubSub.broadcast(
      MermaidLiveSsr.PubSub,
      @fsm_updates_channel,
      {:fsm_error, error}
    )
  end
end
