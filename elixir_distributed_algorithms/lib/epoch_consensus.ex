defmodule DistributedAlgorithmsApp.EpochConsensus do
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.UniformConsensus
  alias DistributedAlgorithmsApp.AbstractionIdUtils

  # checked
  ### only the leader
  def send_proposal_event(message, state) do
    topic =
      Map.get(message, :FromAbstractionId)
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)
    new_tmpval = GenServer.call(state.pl_memory_pid, {:update_tmpval, message.epPropose.value, topic})
    modified_topic_state = topic_state |> Map.put(:tmpval, new_tmpval)
    new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

    {epoch_consensus_timestamp, _leader} = modified_topic_state.ets_leader_pair
    source_abstraction_id = "app.uc[" <> topic <> "].ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"
    destination_abstraction_id = source_abstraction_id <> "].beb"

    ep_internal_read_message = %Proto.Message {
      FromAbstractionId: "app.pl", # be careful with the abstractions
      ToAbstractionId: "app.pl", # be careful with the abstractions
      type: :BEB_BROADCAST,
      bebBroadcast: %Proto.BebBroadcast {
        message: %Proto.Message {
          FromAbstractionId: source_abstraction_id, # be careful with the abstractions
          ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
          type: :EpInternalRead,
          epInternalRead: %Proto.EpInternalRead {}
        }
      }
    }

    Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(ep_internal_read_message, x, new_state) end)
  end

  # checked
  def deliver_ep_internal_read_message(message, state) do
    topic = message
      |> get_in(Enum.map([:bebDeliver, :message, :FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()

    epoch_consensus_timestamp = message
      |> get_in(Enum.map([:bebDeliver, :message, :ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_epoch_consensus_timestamp()

    source_abstraction_id = "app.uc[" <> topic <> "].ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"
    destination_abstraction_id = source_abstraction_id <> ".pl"

    {valts, val} = state.valts_val_pair

    state_message = %Proto.Message {
      FromAbstractionId: source_abstraction_id, # be careful with the abstractions
      ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: message.bebDeliver.sender,
        message: %Proto.Message {
          FromAbstractionId: source_abstraction_id, # be careful with the abstractions
          ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
          type: :EP_INTERNAL_STATE,
          epInternalState: %Proto.EpInternalState {
            valueTimestamp: valts,
            value: val
          }
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(state_message, state)
  end

  # checked
  ### only the leader
  def deliver_ep_internal_state_message(message, state) do
    topic = message
      |> get_in(Enum.map([:plDeliver, :message, :FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)

    epoch_consensus_timestamp = message
      |> get_in(Enum.map([:plDeliver, :message, :ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_epoch_consensus_timestamp()

    N = length(state.process_id_structs)
    rank = rem(message.plDeliver.sender.rank, N)
    value_timestamp = message.plDeliver.message.epInternalState.valueTimestamp
    value = message.plDeliver.message.epInternalState.value
    new_states = GenServer.call(state.pl_memory_pid, {:update_states_pair, rank, {value_timestamp, value}, topic})

    ### upon #(states) > N/2 ... (only the leader)
    if length(new_states) - Enum.count(new_states, fn x -> x == nil end) > div(N, 2) do
      {_ts, val} = Enum.max_by(new_states, fn {ts, val} -> ts end)
      tmpval =
        if val.v != nil do
          GenServer.call(state.pl_memory_pid, {:update_tmpval, val, topic})
        else
          state.tmpval
        end

      GenServer.call(state.pl_memory_pid, {:reset_states, topic})
      modified_topic_state = topic_state
        |> Map.put(:tmpval, tmpval)
        |> Map.put(:states, [])

      new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))
      source_abstraction_id = "app.uc[" <> topic <> "].ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"
      destination_abstraction_id = source_abstraction_id <> ".beb"

      ep_internal_write = %Proto.Message {
        FromAbstractionId: "app.pl", # be careful with the abstractions
        ToAbstractionId: "app.pl", # be careful with the abstractions
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            FromAbstractionId: source_abstraction_id, # be careful with the abstractions
            ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
            type: :EP_INTERNAL_WRITE,
            epInternalWrite: %Proto.EpInternalWrite {
              value: tmpval
            }
          }
        }
      }

      Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(ep_internal_write, x, new_state) end)
    end
  end

  # checked
  def deliver_ep_internal_write_message(message, state) do
    topic = message
      |> get_in(Enum.map([:bebDeliver, :message, :FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)

    epoch_consensus_timestamp = message
      |> get_in(Enum.map([:bebDeliver, :message, :ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_epoch_consensus_timestamp()

    value = message.bebDeliver.message.epInternalWrite.value
    {ets, _leader} = state.ets_leader_pair
    new_valts_val_pair = GenServer.call(state.pl_memory_pid, {:update_valts_val_pair, {ets, value}, topic})
    modified_topic_state = topic_state
      |> Map.put(:valts_val_pair, new_valts_val_pair)
    new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

    source_abstraction_id = "app.uc[" <> topic <> "].ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"
    destination_abstraction_id = source_abstraction_id <> ".pl"

    ep_internal_accept_message = %Proto.Message {
      FromAbstractionId: "app.pl", # be careful with the abstractions
      ToAbstractionId: "app.pl", # be careful with the abstractions
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: message.bebDeliver.sender,
        message: %Proto.Message {
          FromAbstractionId: source_abstraction_id, # be careful with the abstractions
          ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
          type: :EP_INTERNAL_ACCEPT,
          epInternalAccept: %Proto.EpInternalAccept {}
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(ep_internal_accept_message, new_state)
  end

  # checked
  ### only the leader
  def deliver_ep_internal_accept_message(message, state) do
    topic = message
      |> get_in(Enum.map([:plDeliver, :message, :FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)

    epoch_consensus_timestamp = message
      |> get_in(Enum.map([:plDeliver, :message, :ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_epoch_consensus_timestamp()

    N = length(state.process_id_structs)
    new_accepted = GenServer.call(state.pl_memory_pid, {:update_accepted, state.accepted + 1, topic})

    ### only the leader
    if new_accepted > div(N, 2) do
      GenServer.call(state.pl_memory_pid, {:update_accepted, 0, topic})

      modified_topic_state = topic_state |> Map.put(:accepted, 0)
      new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

      source_abstraction_id = "app.uc[" <> topic <> "].ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"
      destination_abstraction_id = source_abstraction_id <> ".beb"

      ep_internal_decided_message = %Proto.Message {
        FromAbstractionId: "app.pl", # be careful with the abstractions
        ToAbstractionId: "app.pl", # be careful with the abstractions
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            FromAbstractionId: source_abstraction_id, # be careful with the abstractions
            ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
            type: :EP_INTERNAL_DECIDED,
            epInternalDecided: %Proto.EpInternalDecided {
              value: modified_topic_state.tmpval
            }
          }
        }
      }

      Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(ep_internal_decided_message, x, new_state) end)
    end
  end

  # checked
  def deliver_ep_internal_decided_message(message, state) do
    topic = message
      |> get_in(Enum.map([:bebDeliver, :message, :FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()

    epoch_consensus_timestamp = message
      |> get_in(Enum.map([:bebDeliver, :message, :ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_epoch_consensus_timestamp()

    source_abstraction_id = "app.uc[" <> topic <> "].ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"
    destination_abstraction_id = "app.uc[" <> topic <> "]"
    {ets, _leader} = state.ets_leader_pair

    ep_decide_message = %Proto.Message {
      FromAbstractionId: source_abstraction_id, # be careful with the abstractions
      ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
      type: :EP_DECIDE,
      epDecide: %Proto.EpDecide {
        ets: ets,
        value: message.bebDeliver.message.value
      }
    }

    UniformConsensus.deliver_ep_decide_event(ep_decide_message, state)
  end

  # checked
  def receive_ep_abort_message(message, state) do
    topic = message
      |> get_in(Enum.map([:FromAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_topic_name()

    topic_state = Map.get(state.consensus_dictionary, topic)
    epoch_consensus_timestamp = message
      |> get_in(Enum.map([:ToAbstractionId], &Access.key!(&1)))
      |> AbstractionIdUtils.extract_epoch_consensus_timestamp()

    source_abstraction_id = "app.uc[" <> topic <> "].ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"
    destination_abstraction_id = "app.uc[" <> topic <> "]"

    {valts, val} = topic_state.valts_val_pair
    {ets, _leader} = topic_state.ets_leader_pair

    ep_aborted_message = %Proto.Message {
      FromAbstractionId: source_abstraction_id, # be careful with the abstractions
      ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
      type: :EP_ABORTED,
      epAborted: %Proto.EpAborted {
        ets: ets,
        value: val,
        valueTimestamp: valts
      }
    }

    UniformConsensus.deliver_ep_aborted_event(ep_aborted_message, state)
    # halt?
  end

end
