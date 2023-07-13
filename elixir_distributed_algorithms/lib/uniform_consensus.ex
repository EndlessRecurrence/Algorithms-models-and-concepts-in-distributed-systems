defmodule DistributedAlgorithmsApp.UniformConsensus do
  alias DistributedAlgorithmsApp.EpochConsensus
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.AbstractionIdUtils

  # checked
  def trigger_uc_propose_event(message, state) do
    IO.puts("UC: Uc propose event")

    topic =
      Map.get(message, :ToAbstractionId)
      |> AbstractionIdUtils.extract_topic_name()

    GenServer.call(state.pl_memory_pid, {:update_val, message.ucPropose.value, topic})
    modified_topic_state = Map.get(state.consensus_dictionary, topic) |> Map.put(:val, message.ucPropose.value)
    new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

    send_proposal_event(new_state, topic)
  end

  # checked
  def receive_ec_startepoch_event(message, state) do
    IO.puts("UC: Ec startepoch event")

    topic =
      Map.get(message, :ToAbstractionId)
      |> AbstractionIdUtils.extract_topic_name()
    newts_newl_pair = GenServer.call(state.pl_memory_pid, {:update_newts_newl_pair, {message.ecStartEpoch.newTimestamp, message.ecStartEpoch.newLeader}, topic})

    modified_topic_state = Map.get(state.consensus_dictionary, topic) |> Map.put(:newts_newl_pair, newts_newl_pair)
    new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))
    {epoch_consensus_timestamp, _leader} = modified_topic_state.ets_leader_pair

    source_abstraction_id = "app.uc[" <> topic <> "]"
    destination_abstraction_id = "app.uc[" <> topic <> "]" <> ".ep[" <> Integer.to_string(epoch_consensus_timestamp) <> "]"

    ep_abort_message = %Proto.Message {
      FromAbstractionId: source_abstraction_id, # be careful with the abstractions
      ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
      type: :EP_ABORT,
      epAbort: %Proto.EpAbort {}
    }

    EpochConsensus.receive_ep_abort_message(ep_abort_message, new_state)
  end

  # checked
  def deliver_ep_aborted_event(message, state) do
    IO.puts("UC: Ep aborted event")

    topic =
      Map.get(message, :ToAbstractionId)
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)
    {epoch_consensus_timestamp, _leader} = topic_state.ets_leader_pair

    new_state =
      if topic_state.ts == epoch_consensus_timestamp do
        GenServer.call(state.pl_memory_pid, {:update_ets_leader_pair, topic_state.newts_newl_pair, topic})
        GenServer.call(state.pl_memory_pid, {:update_proposed_flag, false, topic})
        modified_topic_state =
          topic_state
          |> Map.put(:ets_leader_pair, topic_state.newts_newl_pair)
          |> Map.put(:proposed, false)

        state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))
      else
        state
      end

    send_proposal_event(new_state, topic)
  end

  # checked
  defp send_proposal_event(state, topic) do
    IO.puts("UC: proposal event")

    topic_state = Map.get(state.consensus_dictionary, topic)
    leader = Map.get(topic_state, :leader) |> then(fn x -> if x == nil, do: nil, else: x end)

    IO.inspect leader, label: "UC: send_proposal_event -> leader"
    IO.inspect state.process_id_struct, label: "UC: send_proposal_event -> process_id_struct"
    IO.inspect topic_state.val.v, label: "UC: send_proposal_event -> topic_state.val.v"
    IO.inspect topic_state.proposed, label: "UC: send_proposal_event -> topic_state.proposed"

    if leader == state.process_id_struct and topic_state.val.v != nil and topic_state.proposed == false do
      GenServer.call(state.pl_memory_pid, {:update_proposed_flag, true, topic})
      modified_topic_state = topic_state |> Map.put(:proposed, true)
      new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

      {epoch_consensus_timestamp, _leader} = modified_topic_state.ets_leader_pair
      source_abstraction_id = "app.uc[" <> topic <> "]"
      destination_abstraction_id = "app.uc[" <> topic <> "]" <> ".ep[" <> epoch_consensus_timestamp <> "]"

      ep_propose_event = %Proto.Message {
        FromAbstractionId: source_abstraction_id, # be careful with the abstractions
        ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
        type: :EP_PROPOSE,
        epPropose: %Proto.EpPropose {value: topic_state.val}
      }

      EpochConsensus.send_proposal_event(ep_propose_event, new_state)
    end
  end

  # checked
  def deliver_ep_decide_event(message, state) do
    IO.puts("UC: Ep decide event")

    topic =
      Map.get(message, :FromAbstractionId)
      |> AbstractionIdUtils.extract_topic_name()
    topic_state = Map.get(state.consensus_dictionary, topic)
    {ets, _leader} = topic_state.ets_leader_pair

    if topic_state.ts == ets do
      if topic_state.decided == false do
        GenServer.call(state.pl_memory_pid, {:update_decided_flag, true, topic})
        modified_topic_state = topic_state |> Map.put(:decided, true)
        new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

        source_abstraction_id = "app.uc[" <> topic <> "]"
        destination_abstraction_id = "app"

        uc_decide_message = %Proto.Message {
          FromAbstractionId: source_abstraction_id, # be careful with the abstractions
          ToAbstractionId: destination_abstraction_id, # be careful with the abstractions
          type: :UC_DECIDE,
          ucDecide: %Proto.UcDecide {value: message.epDecide.value}
        }

        AppLayer.receive_uc_decide_event(uc_decide_message, new_state)
      end
    end
  end

end
