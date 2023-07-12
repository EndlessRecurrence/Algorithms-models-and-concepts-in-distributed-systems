defmodule DistributedAlgorithmsApp.EventualLeaderDetector do
  alias DistributedAlgorithmsApp.EventuallyPerfectFailureDetector
  alias DistributedAlgorithmsApp.EpochChange
  alias DistributedAlgorithmsApp.ProcessMemory
  alias DistributedAlgorithmsApp.AbstractionIdUtils

  # checked
  def receive_epfd_suspect_event(message, state) do
    abstraction = message |> get_in(Enum.map([:ToAbstractionId], &Access.key!(&1)))
    deliver_trust_event(message.epfdSuspect.process, state, abstraction)
  end

  # checked
  def receive_epfd_restore_event(message, state) do
    abstraction = message |> get_in(Enum.map([:ToAbstractionId], &Access.key!(&1)))
    deliver_trust_event(message.epfdRestore.process, state, abstraction)
  end

  # checked
  defp deliver_trust_event(leader, state, abstraction_id) do
    topic = AbstractionIdUtils.extract_topic_name(abstraction_id)
    topic_state = Map.get(state.consensus_dictionary, topic)

    all_processes = state.process_id_structs |> MapSet.new()
    suspected_processes = state.suspected |> MapSet.new()
    process_with_strongest_rank = all_processes
      |> MapSet.difference(suspected_processes)
      |> MapSet.to_list()
      |> Enum.min_by(fn x -> x.rank end)

    if leader != process_with_strongest_rank do
      new_leader = GenServer.call(state.pl_memory_pid, {:update_leader, process_with_strongest_rank, topic})

      modified_topic_state = Map.put(topic_state, :leader, new_leader)
      new_state = state |> Map.put(:consensus_dictionary, Map.put(state.consensus_dictionary, topic, modified_topic_state))

      epfd_source_abstraction_id = "app.uc[" <> topic <> "].ec.eld"
      epfd_destination_abstraction_id = "app.uc[" <> topic <> "].ec"

      eld_trust_message = %Proto.Message {
        FromAbstractionId: epfd_source_abstraction_id, # be careful with the abstractions
        ToAbstractionId: epfd_destination_abstraction_id, # be careful with the abstractions
        type: :ELD_TRUST,
        eldTrust: %Proto.EldTrust {process: new_leader}
      }

      EpochChange.receive_trust_event(eld_trust_message, new_state)
    end
  end

end
