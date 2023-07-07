defmodule DistributedAlgorithmsApp.EpochChange do
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer

  def receive_trust_event(leader, state) do
    GenServer.call(state.pl_memory_pid, {:update_trusted, leader})
    if leader == state.process_id_struct do
      new_ts = GenServer.call(state.pl_memory_pid, {:update_ts, state.ts + length(state.process_id_structs)})

      newepoch_message = %Proto.Message {
        ToAbstractionId: "app.pl",
        FromAbstractionId: "app.pl",
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            type: :EC_INTERNAL_NEW_EPOCH,
            ecInternalNewEpoch: %Proto.EcInternalNewEpoch {timestamp: new_ts}
          }
        }
      }

      Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(newepoch_message, x, state) end)
    end
  end

  def deliver_broadcasted_newepoch_event(message, state) do
    newts = message.bebDeliver.message.ecInternalNewEpoch.timestamp
    if message.bebDeliver.sender == state.trusted and newts > state.lastts do
      new_lastts = GenServer.call(state.pl_memory_pid, {:update_lastts, state.lastts + newts})
      # trigger <ec, StartEpoch | newts, l> event
    else
      # trigger <pl, Send | l, [NACK]>
      nack_message = %Proto.Message {
        ToAbstractionId: "app.pl",
        FromAbstractionId: "app.pl",
        type: :PL_SEND,
        plSend: %Proto.PlSend {
          destination: message.bebDeliver.sender,
          message: %Proto.Message {
            ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            type: :EC_INTERNAL_NACK,
            ecInternalNack: %Proto.EcInternalNack {}
          }
        }
      }

      PerfectLinkLayer.send_value_to_process(nack_message, state)
    end
  end

  def deliver_pl_nack_event(message, state) do
    if state.trusted == state.process_id_struct do
      new_ts = GenServer.call(state.pl_memory_pid, {:update_ts, state.ts + length(state.process_id_structs)})

      newepoch_message = %Proto.Message {
        ToAbstractionId: "app.pl",
        FromAbstractionId: "app.pl",
        type: :BEB_BROADCAST,
        bebBroadcast: %Proto.BebBroadcast {
          message: %Proto.Message {
            ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
            type: :EC_INTERNAL_NEW_EPOCH,
            ecInternalNewEpoch: %Proto.EcInternalNewEpoch {timestamp: new_ts}
          }
        }
      }

      Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(newepoch_message, x, state) end)
    end
  end
end
