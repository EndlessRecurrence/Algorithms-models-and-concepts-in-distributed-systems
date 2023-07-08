defmodule DistributedAlgorithmsApp.EpochConsensus do
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer

  ### only the leader
  def send_proposal_event(message, state) do
    GenServer.call(state.pl_memory_pid, {:update_tmpval, message.epPropose.value})

    ep_internal_read_message = %Proto.Message {
      FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
      ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
      type: :BEB_BROADCAST,
      bebBroadcast: %Proto.BebBroadcast {
        message: %Proto.Message {
          FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          type: :EpInternalRead,
          epInternalRead: %Proto.EpInternalRead {}
        }
      }
    }

    Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(ep_internal_read_message, x, state) end)
  end

  def deliver_ep_internal_read_message(message, state) do
    state_message = %Proto.Message {
      FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
      ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: message.bebDeliver.sender,
        message: %Proto.Message {
          FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          type: :EP_INTERNAL_STATE,
          epInternalState: %Proto.EpInternalState {
            valueTimestamp: elem(state.valts_val_pair, 0),
            value: %Proto.Value {defined: true, v: elem(state.valts_val_pair, 1)}
          }
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(state_message, state)
  end

  ### only the leader
  def deliver_pl_state(message, state) do
    N = length(state.process_id_structs)
    rank = rem(message.plDeliver.sender.rank, N)
    value_timestamp = message.plDeliver.message.epInternalState.valueTimestamp
    value = message.plDeliver.message.epInternalState.value
    new_states = GenServer.call(state.pl_memory_pid, {:update_states_pair, rank, {value_timestamp, value}})

    ### upon #(states) > N/2 ... (only the leader)
    if length(new_states) > div(N, 2) do
      {ts, val} = Enum.max_by(new_states, fn {ts, val} -> ts end)
      tmpval =
        if val.v != nil do
          GenServer.call(state.pl_memory_pid, {:update_tmpval, val})
        else
          state.tmpval
        end

      GenServer.call(state.pl_memory_pid, :reset_states)

      ep_internal_write = %Proto.Message {
        FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
        ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            type: :EP_INTERNAL_WRITE,
            epInternalWrite: %Proto.EpInternalWrite {
              value: %Proto.Value {defined: true, v: tmpval}
            }
          }
        }
      }
    end
  end

  def deliver_ep_internal_write_message(message, state) do
    value = message.bebDeliver.message.epInternalWrite.value
    ets = state.ets_leader_pair |> elem(0)
    GenServer.call(state.pl_memory_pid, {:update_valts_val_pair, {ets, value}})

    ep_internal_accept_message = %Proto.Message {
      FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
      ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: message.bebDeliver.sender,
        message: %Proto.Message {
          FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          type: :EP_INTERNAL_ACCEPT,
          epInternalAccept: %Proto.EpInternalAccept {}
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(ep_internal_accept_message, state)
  end

  ### only the leader
  def deliver_ep_internal_accept_message(message, state) do
    N = length(state.process_id_structs)
    new_accepted = GenServer.call(state.pl_memory_pid, {:update_accepted, state.accepted + 1})

    ### only the leader
    if new_accepted > div(N, 2) do
      GenServer.call(state.pl_memory_pid, {:update_accepted, 0})

      ep_internal_decided_message = %Proto.Message {
        FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
        ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            type: :EP_INTERNAL_DECIDED,
            epInternalDecided: %Proto.EpInternalDecided {
              value: %Proto.Value{decided: true, v: state.tmpval}
            }
          }
        }
      }

      Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(ep_internal_decided_message, x, state) end)
    end
  end

  def deliver_ep_internal_decided_message(message, state) do
    # trigger <ep, Decide | v>
  end

  def receive_ep_abort_message(message, state) do
    # trigger <ep, Aborted | (valts, val)>
    # halt;
  end

end
