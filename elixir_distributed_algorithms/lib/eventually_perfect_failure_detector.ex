defmodule DistributedAlgorithmsApp.EventuallyPerfectFailureDetector do
  use GenServer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.EventualLeaderDetector
  alias DistributedAlgorithmsApp.AbstractionIdUtils
  # require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  # checked
  @impl true
  def init({initial_state, topic}) do
    IO.inspect initial_state, label: "EPFD: initial state", limit: :infinity
    # IO.inspect initial_state, label: "EPFD initial state"
    delay = Map.get(initial_state.consensus_dictionary, topic)
      |> Map.get(:delay)

    Process.send_after(self(), :timeout, delay)

    state = initial_state
      |> Map.put(:topic, topic)

    {:ok, state}
  end

  # checked
  @impl true
  def handle_info(:timeout, state) do
    IO.inspect state, label: "EPFD: timeout state", limit: :infinity
    # IO.puts("EPFD #{:erlang.pid_to_list(self())} timed out.")
    topic = state.topic
    topic_state = Map.get(state.consensus_dictionary, topic)
    new_delay = if topic_state.alive != [] and topic_state.suspected != [], do: topic_state.delay + topic_state.initial_delay, else: topic_state.delay

    updated_suspected =
      Enum.reduce(state.process_id_structs, topic_state.suspected, fn x, suspected ->
        epfd_source_abstraction_id = "app.uc[" <> topic <> "].ec.eld.epfd"
        epfd_destination_abstraction_id = "app.uc[" <> topic <> "].ec.eld"

        new_suspected =
          cond do
            Enum.member?(topic_state.alive, x) == false and Enum.member?(suspected, x) == false ->
              modified_topic_state = Map.put(topic_state, :suspected, Enum.uniq([x | suspected]))
              state_parameter = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

              epfd_suspect_message = %Proto.Message {
                FromAbstractionId: epfd_source_abstraction_id, # be careful with the abstractions
                ToAbstractionId: epfd_destination_abstraction_id, # be careful with the abstractions
                type: :EPFD_SUSPECT,
                epfdSuspect: %Proto.EpfdSuspect {process: x}
              }

              EventualLeaderDetector.receive_epfd_suspect_event(epfd_suspect_message, state_parameter)
              Enum.uniq([x | suspected])
            Enum.member?(topic_state.alive, x) and Enum.member?(suspected, x) ->
              modified_topic_state = Map.put(topic_state, :suspected, Enum.filter(suspected, fn y -> y != x end))
              state_parameter = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

              epfd_restore_message = %Proto.Message {
                FromAbstractionId: epfd_source_abstraction_id, # be careful with the abstractions
                ToAbstractionId: epfd_destination_abstraction_id, # be careful with the abstractions
                type: :EPFD_RESTORE,
                epfdRestore: %Proto.EpfdRestore {process: x}
              }

              EventualLeaderDetector.receive_epfd_restore_event(epfd_restore_message, state_parameter)
              Enum.filter(suspected, fn y -> y != x end)
            true -> suspected
          end

        heartbeat_request_message = %Proto.Message {
          FromAbstractionId: epfd_source_abstraction_id <> ".pl", # be careful with the abstractions
          ToAbstractionId: epfd_source_abstraction_id <> ".pl", # be careful with the abstractions
          type: :PL_SEND,
          plSend: %Proto.PlSend {
            destination: x,
            message: %Proto.Message {
              FromAbstractionId: epfd_source_abstraction_id, # be careful with the abstractions
              ToAbstractionId: epfd_source_abstraction_id, # be careful with the abstractions
              type: :EPFD_INTERNAL_HEARTBEAT_REQUEST,
              epfdInternalHeartbeatRequest: %Proto.EpfdInternalHeartbeatRequest{}
            }
          }
        }

        PerfectLinkLayer.send_value_to_process(heartbeat_request_message, state)
        new_suspected
      end)

    modified_topic_state = topic_state
      |> Map.put(:delay, new_delay)
      |> Map.put(:alive, [])
      |> Map.put(:suspected, updated_suspected)

    new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

    Process.send_after(self(), :timeout, new_delay)
    {:noreply, new_state}
  end

  # checked
  @impl true
  def handle_info({:EPFD_INTERNAL_HEARTBEAT_REQUEST, message, pl_state}, state) do
    IO.inspect state, label: "EPFD: heartbeat request state", limit: :infinity
    topic = message
      |> get_in(Enum.map([:plDeliver, :message, :FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()

    # IO.inspect message, label: "Request heartbeat message caught in generic handler @ EFPD", limit: :infinity
    abstraction_id = "app.uc[" <> topic <> "].ec.eld.epfd"

    heartbeat_reply_message = %Proto.Message {
      FromAbstractionId: abstraction_id <> ".pl", # be careful with the abstractions
      ToAbstractionId: abstraction_id <> ".pl", # be careful with the abstractions
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: message.plDeliver.sender,
        message: %Proto.Message {
          FromAbstractionId: abstraction_id, # be careful with the abstractions
          ToAbstractionId: abstraction_id, # be careful with the abstractions
          type: :EPFD_INTERNAL_HEARTBEAT_REPLY,
          epfdInternalHeartbeatReply: %Proto.EpfdInternalHeartbeatReply{}
        }
      }
    }

    new_state = Map.merge(pl_state, state)
    PerfectLinkLayer.send_value_to_process(heartbeat_reply_message, new_state)
    {:noreply, new_state}
  end

  # checked
  @impl true
  def handle_info({:EPFD_INTERNAL_HEARTBEAT_REPLY, message, pl_state}, state) do
    IO.inspect state, label: "EPFD: heartbeat reply state", limit: :infinity

    topic = message
      |> get_in(Enum.map([:plDeliver, :message, :FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)

    # IO.inspect message, label: "Reply heartbeat message caught in generic handler @ EFPD", limit: :infinity
    updated_alive_list = [message.plDeliver.sender | Map.get(topic_state, :alive)] |> Enum.uniq()

    modified_topic_state = Map.put(topic_state, :alive, updated_alive_list)
    state_with_updated_alive_list = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

    new_state = Map.merge(pl_state, state_with_updated_alive_list)
    {:noreply, new_state}
  end

end
