defmodule DistributedAlgorithmsApp.EventuallyPerfectFailureDetector do
  use GenServer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(initial_state) do
    IO.inspect initial_state, label: "EPFD initial state"
    Process.send_after(self(), :timeout, initial_state.delay)
    {:ok, Map.put(initial_state, :initial_delay, initial_state.delay)}
  end

  @impl true
  def handle_info(:timeout, state) do
    IO.puts("EPFD #{:erlang.pid_to_list(self())} timed out.")
    new_delay = if state.alive != [] and state.suspected != [], do: state.delay + state.initial_delay, else: state.delay

    updated_suspected =
      Enum.reduce(state.process_id_structs, state.suspected, fn x, suspected ->
        new_suspected =
          cond do
            Enum.member?(state.alive, x) == false and Enum.member?(suspected, x) == false ->
              # pass <Suspected | P> event upwards
              [x | suspected]
            Enum.member?(state.alive, x) and Enum.member?(suspected, x) ->
              # pass <Restore | P> event upwards
              Enum.filter(suspected, fn y -> y != x end)
            true -> suspected
          end

        heartbeat_request_message = %Proto.Message {
          ToAbstractionId: "app.pl",
          FromAbstractionId: "app.epfd.pl",
          type: :PL_SEND,
          plSend: %Proto.PlSend {
            destination: x,
            message: %Proto.Message {
              ToAbstractionId: "app.pl",
              FromAbstractionId: "app.epfd.pl",
              type: :EPFD_INTERNAL_HEARTBEAT_REQUEST,
              epfdInternalHeartbeatRequest: %Proto.EpfdInternalHeartbeatRequest{}
            }
          }
        }

        PerfectLinkLayer.send_value_to_process(heartbeat_request_message, state)
        new_suspected
      end)

    new_state = state
      |> Map.put(:delay, new_delay)
      |> Map.put(:alive, [])
      |> Map.put(:suspected, updated_suspected)

    Process.send_after(self(), :timeout, new_delay)
    {:noreply, new_state}
  end

  def receive_message(_message, _state) do

  end

  def deliver_message(_message, _state) do

  end

end
