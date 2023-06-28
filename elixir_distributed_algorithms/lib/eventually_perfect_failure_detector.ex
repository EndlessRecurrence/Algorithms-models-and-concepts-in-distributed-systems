defmodule DistributedAlgorithmsApp.EventuallyPerfectFailureDetector do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(%{alive: _alive, suspected: _suspected, delay: delay} = initial_state) do
    IO.inspect initial_state, label: "EPFD initial state"
    Process.send_after(self(), :timeout, delay)
    {:ok, initial_state}
  end

  @impl true
  def handle_info(:timeout, %{alive: _alive, suspected: _suspected, delay: delay} = state) do
    IO.puts("EPFD #{:erlang.pid_to_list(self())} timed out.")
    Process.send_after(self(), :timeout, delay)
    {:noreply, state}
  end

  def receive_message(_message, _state) do

  end

  def deliver_message(_message, _state) do

  end

end
