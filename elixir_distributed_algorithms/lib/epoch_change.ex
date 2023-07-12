defmodule DistributedAlgorithmsApp.EpochChange do
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.UniformConsensus
  alias DistributedAlgorithmsApp.AbstractionIdUtils

  # checked
  def receive_trust_event(message, state) do
    IO.inspect state, label: "Trust event", limit: :infinity

    topic = message
      |> get_in(Enum.map([:ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()

    topic_state = Map.get(state.consensus_dictionary, topic)
    leader = GenServer.call(state.pl_memory_pid, {:update_trusted, message.eldTrust.process, topic})

    if leader == state.process_id_struct do
      new_ts = GenServer.call(state.pl_memory_pid, {:update_ts, state.ts + length(state.process_id_structs), topic})
      modified_topic_state = topic_state
        |> Map.put(:trusted, leader)
        |> Map.put(:ts, new_ts)
      new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

      source_abstraction_id = "app.uc[" <> topic <> "].ec"
      destination_abstraction_id = "app.uc[" <> topic <> "].ec.beb"

      newepoch_message = %Proto.Message {
        FromAbstractionId: "app.pl",
        ToAbstractionId: "app.pl",
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            FromAbstractionId: source_abstraction_id, # be careful with the abstractions
            ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
            type: :EC_INTERNAL_NEW_EPOCH,
            ecInternalNewEpoch: %Proto.EcInternalNewEpoch {timestamp: new_ts}
          }
        }
      }

      Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(newepoch_message, x, new_state) end)
    end
  end

  # checked
  def deliver_ep_internal_newepoch_message(message, state) do
    IO.inspect state, label: "Newepoch event", limit: :infinity
    topic = message
      |> get_in(Enum.map([:bebDeliver, :message, :ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()
    IO.inspect topic, label: "TOPIC"
    topic_state = Map.get(state.consensus_dictionary, topic)

    newts = message
      |> get_in(Enum.map([:bebDeliver, :message, :ecInternalNewEpoch, :timestamp], &Access.key!(&1)))

    # if topic_state == nil do
    #   IO.inspect state.consensus_dictionary, label: "Consensus dictionary", limit: :infinity
    # end

    if message.bebDeliver.sender == topic_state.trusted and newts > topic_state.lastts do
      new_lastts = GenServer.call(state.pl_memory_pid, {:update_lastts, topic_state.lastts + newts, topic})

      modified_topic_state = topic_state
        |> Map.put(:lastts, new_lastts)
      new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

      source_abstraction_id = "app.uc[" <> topic <> "].ec"
      destination_abstraction_id = "app.uc[" <> topic <> "]"

      start_epoch_message = %Proto.Message {
        FromAbstractionId: source_abstraction_id, # be careful with the abstractions
        ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
        type: :EC_START_EPOCH,
        ecStartEpoch: %Proto.EcStartEpoch {
          newTimestamp: newts,
          newLeader: message.bebDeliver.sender
        }
      }

      UniformConsensus.receive_ec_startepoch_event(start_epoch_message, new_state)
    else
      source_abstraction_id = "app.uc[" <> topic <> "].ec"
      destination_abstraction_id = "app.uc[" <> topic <> "].ec.pl"

      nack_message = %Proto.Message {
        FromAbstractionId: "app.pl",
        ToAbstractionId: "app.pl",
        type: :PL_SEND,
        plSend: %Proto.PlSend {
          destination: message.bebDeliver.sender,
          message: %Proto.Message {
            FromAbstractionId: source_abstraction_id, # be careful with the abstractions
            ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
            type: :EC_INTERNAL_NACK,
            ecInternalNack: %Proto.EcInternalNack {}
          }
        }
      }

      PerfectLinkLayer.send_value_to_process(nack_message, state)
    end
  end

  # checked
  def deliver_ec_internal_nack_message(message, state) do
    topic = message
      |> get_in(Enum.map([:plDeliver, :message, :ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)

    if topic_state.trusted == state.process_id_struct do
      new_ts = GenServer.call(state.pl_memory_pid, {:update_ts, topic_state.ts + length(state.process_id_structs), topic})

      modified_topic_state = topic_state
        |> Map.put(:ts, new_ts)
      new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

      source_abstraction_id = "app.uc[" <> topic <> "].ec"
      destination_abstraction_id = "app.uc[" <> topic <> "].ec.beb"

      newepoch_message = %Proto.Message {
        FromAbstractionId: "app.pl",
        ToAbstractionId: "app.pl",
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            FromAbstractionId: source_abstraction_id, # be careful with the abstractions, the hub doesn't recognize this one...
            ToAbstractionId: destination_abstraction_id, # be careful with the abstractions, the hub doesn't recognize this one...
            type: :EC_INTERNAL_NEW_EPOCH,
            ecInternalNewEpoch: %Proto.EcInternalNewEpoch {timestamp: new_ts}
          }
        }
      }

      Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(newepoch_message, x, new_state) end)
    end
  end
end
