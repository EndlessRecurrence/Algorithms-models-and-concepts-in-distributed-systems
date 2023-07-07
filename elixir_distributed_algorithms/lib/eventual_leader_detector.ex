defmodule DistributedAlgorithmsApp.EventualLeaderDetector do
  alias DistributedAlgorithmsApp.EventuallyPerfectFailureDetector
  alias DistributedAlgorithmsApp.ProcessMemory

  def receive_epfd_suspect_event(process_struct, state) do
    deliver_trust_event(process_struct, state)
  end

  def receive_epfd_restore_event(process_struct, state) do
    deliver_trust_event(process_struct, state)
  end

  defp deliver_trust_event(leader, state) do
    GenServer.call(state.pl_memory_pid, {:update_suspected_list, state.suspected})
    all_processes = state.process_id_structs |> MapSet.new()
    suspected_processes = state.suspected |> MapSet.new()
    process_with_strongest_rank = all_processes
      |> MapSet.difference(suspected_processes)
      |> MapSet.to_list()
      |> Enum.min_by(fn x -> x.rank end)

    if leader != process_with_strongest_rank do
      GenServer.call(state.pl_memory_pid, {:update_leader, process_with_strongest_rank})
      EpochChange.receive_trust_event(leader, state)
    end
  end

end
