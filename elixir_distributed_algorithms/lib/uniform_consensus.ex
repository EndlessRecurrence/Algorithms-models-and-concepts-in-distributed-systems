defmodule DistributedAlgorithmsApp.UniformConsensus do

  def trigger_uc_propose_event(value, state) do
    GenServer.call(state.pl_memory_pid, {:update_val, value})
  end

  def receive_ec_startepoch_event(message, state) do
    newts_newl_pair = {message.ecStartEpoch.newTimestamp, message.ecStartEpoch.newLeader}
    GenServer.call(state.pl_memory_pid, {:update_newts_newl_pair, newts_newl_pair})
    # trigger <ep.ets, Abort>
  end

  def receive_ep_aborted_event(message, state) do
    new_state =
      if state.ts == elem(state.ets_leader_pair, 0) do
        GenServer.call(state.pl_memory_pid, {:update_ets_leader_pair, state.newts_newl_pair})
        GenServer.call(state.pl_memory_pid, {:update_proposed_flag, false})
        state |> Map.put(proposed: false)
        # Initialize a new instance ep.ets of epoch consensus with timestamp ets,
        # leader l, and state state;
      else
        state
      end

    if new_state.leader == new_state.process_id_struct and new_state.val.v != nil and new_state.proposed == false do
      GenServer.call(state.pl_memory_pid, {:update_proposed_flag, true})
      # trigger <ep.ets, Propose | val>
    end
  end

  def receive_ep_decide_event(message, state) when state.ts == elem(state.ets_leader_pair, 0) do
    if state.decided == false do
      GenServer.call(state.pl_memory_pid, {:update_decided_flag, true})
      # trigger <uc, Decide | v>
    end
  end

end
