defmodule DistributedAlgorithmsApp.EventuallyPerfectFailureDetector do
  use GenServer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.EventualLeaderDetector
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
              EventualLeaderDetector.receive_epfd_suspect_event(x, Map.put(state, :suspected, Enum.uniq([x | suspected])))
              Enum.uniq([x | suspected])
            Enum.member?(state.alive, x) and Enum.member?(suspected, x) ->
              EventualLeaderDetector.receive_epfd_restore_event(x, Map.put(state, :suspected, Enum.filter(suspected, fn y -> y != x end)))
              Enum.filter(suspected, fn y -> y != x end)
            true -> suspected
          end

        heartbeat_request_message = %Proto.Message {
          ToAbstractionId: "app.pl",
          FromAbstractionId: "app.pl",
          type: :PL_SEND,
          plSend: %Proto.PlSend {
            destination: x,
            message: %Proto.Message {
              ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
              FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
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

  @impl
  def handle_info({:EPFD_INTERNAL_HEARTBEAT_REQUEST, message, pl_state}, current_state) do
    IO.inspect message, label: "Request heartbeat message caught in generic handler @ EFPD", limit: :infinity

    heartbeat_reply_message = %Proto.Message {
      ToAbstractionId: "app.pl",
      FromAbstractionId: "app.pl",
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: message.plDeliver.sender,
        message: %Proto.Message {
          ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          type: :EPFD_INTERNAL_HEARTBEAT_REPLY,
          epfdInternalHeartbeatReply: %Proto.EpfdInternalHeartbeatReply{}
        }
      }
    }

    new_state = Map.merge(pl_state, current_state)
    PerfectLinkLayer.send_value_to_process(heartbeat_reply_message, new_state)
    {:noreply, new_state}
  end

  @impl
  def handle_info({:EPFD_INTERNAL_HEARTBEAT_REPLY, message, pl_state}, current_state) do
    IO.inspect message, label: "Reply heartbeat message caught in generic handler @ EFPD", limit: :infinity
    updated_alive_list = [message.plDeliver.sender | Map.get(current_state, :alive)] |> Enum.uniq()
    state_with_new_alive_list = Map.put(current_state, :alive, updated_alive_list)
    new_state = Map.merge(pl_state, state_with_new_alive_list)
    {:noreply, new_state}
  end

end
