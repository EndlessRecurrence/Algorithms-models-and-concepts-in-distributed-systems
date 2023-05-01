defmodule DistributedAlgorithmsApp.AppLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.NnAtomicRegisterLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  require Logger

  def receive_message(message, state) do
    case message.type do
      :PL_DELIVER -> receive_pl_deliver_message(message, state)
      :BEB_DELIVER -> receive_beb_deliver_message(message, state)
    end
  end

  defp receive_pl_deliver_message(message, state) do
    case message.plDeliver.message.type do
      :PROC_DESTROY_SYSTEM -> Logger.info("APP_LAYER: Hub destroyed process system.")
      :PROC_INITIALIZE_SYSTEM -> initialize_system(message, state)
      :APP_BROADCAST -> send_broadcast_message(message, state)
      :APP_WRITE -> send_nnar_broadcast_read(message, state)
    end
  end

  defp receive_beb_deliver_message(message, state) do
    case message.bebDeliver.message.type do
      :APP_VALUE -> receive_app_value_message(message, state)
      :NNAR_INTERNAL_READ -> receive_nnar_internal_read_message(message, state)
      :NNAR_INTERNAL_VALUE -> receive_nnar_internal_value_message(message, state)
    end
  end

  defp receive_nnar_internal_read_message(message, state) do
    keys = [:bebDeliver, :message, :nnarInternalRead, :readId]
    read_id_received = get_in(message, Enum.map(keys, &Access.key!(&1)))
    Logger.info("APP_LAYER: Received NNAR_INTERNAL_READ with rid=#{read_id_received}")
    IO.inspect message, label: "APP_LAYER -> NNAR_INTERNAL_READ", limit: :infinity

    updated_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: "app.nnar[?].pl",
      ToAbstractionId: "app.nnar[?].pl",
      plSend: %Proto.PlSend {
        destination: message.bebDeliver.sender,
        message: %Proto.Message {
          type: :NNAR_INTERNAL_VALUE,
          FromAbstractionId: "app.nnar[?]",
          ToAbstractionId: "app.nnar[?]",
          nnarInternalValue: %Proto.NnarInternalValue {
            readId: read_id_received,
            timestamp: state.timestamp_rank_struct.timestamp,
            writerRank: state.timestamp_rank_struct.writer_rank,
            value: state.timestamp_rank_struct.value
          }
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(updated_message, state)
  end

  defp receive_nnar_internal_value_message(message, _state) do
    Logger.info("APP_LAYER: Received NNAR_INTERNAL_VALUE")
    IO.inspect message, label: "APP_LAYER -> NNAR_INTERNAL_VALUE", limit: :infinity
  end

  defp send_broadcast_message(message, state) do
    app_value_message = %Proto.Message {type: :APP_VALUE, appValue: %Proto.AppValue {value: message.plDeliver.message.appBroadcast.value}}

    broadcasted_message = %Proto.Message {
      type: :BEB_BROADCAST,
      FromAbstractionId: "app",
      ToAbstractionId: "app.beb",
      bebBroadcast: %Proto.BebBroadcast {message: app_value_message}
    }

    Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(broadcasted_message, x, state) end)
    response_message_to_hub = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: "app",
      ToAbstractionId: "app.pl",
      plSend: %Proto.PlSend {
        destination: %Proto.ProcessId {host: state.hub_address, port: state.hub_port, owner: "hub", index: 0, rank: 0},
        message: app_value_message
      }
    }

    PerfectLinkLayer.send_value_to_hub(response_message_to_hub, state)
  end

  defp send_nnar_broadcast_read(message, state) do
    NnAtomicRegisterLayer.write_value(message, state)
  end

  def receive_app_value_message(message, state) do
    broadcasted_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: "app",
      ToAbstractionId: "app.pl",
      plSend: %Proto.PlSend {
        destination: %Proto.ProcessId {host: state.hub_address, port: state.hub_port, owner: "hub", index: 0, rank: 0},
        message: %Proto.Message {type: :APP_VALUE, appValue: message.bebDeliver.message.appValue}
      }
    }

    PerfectLinkLayer.send_value_to_hub(broadcasted_message, state)
  end

  def initialize_system(message, state) do
    broadcasted_process_id_structs_from_hub = message.plDeliver.message.procInitializeSystem.processes

    condition_lambda = fn x -> x.owner == state.owner and x.index == state.process_index end
    process_id_struct = broadcasted_process_id_structs_from_hub |> Enum.filter(fn x -> condition_lambda.(x) end) |> Enum.at(0)
    other_process_id_structs = broadcasted_process_id_structs_from_hub |> Enum.reject(fn x -> condition_lambda.(x) end)

    GenServer.cast(state.pl_memory_pid, {:save_process_id_structs, other_process_id_structs, process_id_struct})
    GenServer.cast(state.pl_memory_pid, {:save_system_id, message.systemId})
  end

end
