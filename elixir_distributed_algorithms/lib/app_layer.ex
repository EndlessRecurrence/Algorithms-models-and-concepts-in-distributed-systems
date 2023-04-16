defmodule DistributedAlgorithmsApp.AppLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.PerfectLinkHandler
  require Logger

  def receive_message(message, state) do
    # checked
    case message.type do
      :PL_DELIVER -> receive_pl_deliver_message(message, state)
      :BEB_DELIVER -> receive_beb_deliver_message(message, state)
    end
  end

  defp receive_pl_deliver_message(message, state) do
    # checked
    case message.plDeliver.message.type do
      :PROC_DESTROY_SYSTEM -> Logger.info("APP_LAYER: Hub destroyed process system.")
      :PROC_INITIALIZE_SYSTEM -> initialize_system(message, state)
      :APP_BROADCAST -> send_broadcast_message(message, state)
    end
  end

  defp receive_beb_deliver_message(message, state) do
    # checked
    case message.bebDeliver.message.type do
      :APP_VALUE -> receive_app_value_message(message, state)
    end
  end

  defp send_broadcast_message(message, state) do
    # checked
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

    PerfectLinkHandler.send_broadcast_value_to_hub(response_message_to_hub, state)
  end

  def receive_app_value_message(message, state) do
    # %Proto.Message {
    #   type: :BEB_DELIVER,
    #   FromAbstractionId: "app.beb",
    #   ToAbstractionId: "app",
    #   bebDeliver: %Proto.BebDeliver {
    #     sender: sender,
    #     message: %Proto.Message {
    #       type: :APP_VALUE,
    #       appValue: %Proto.AppValue {
    #         value: %Proto.Value{defined: true, v: -1}
    #       }
    #     }
    #   }
    # }

    broadcasted_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: "app",
      ToAbstractionId: "app.pl",
      plSend: %Proto.PlSend {
        destination: %Proto.ProcessId {host: state.hub_address, port: state.hub_port, owner: "hub", index: 0, rank: 0},
        message: %Proto.Message {type: :APP_VALUE, appValue: message.bebDeliver.message.appValue}
      }
    }

    PerfectLinkHandler.send_broadcast_value_to_hub(broadcasted_message, state)
  end

  def initialize_system(message, state) do
    # checked
    IO.inspect message, label: "APP_LAYER - PL_DELIVER_MESSAGE", limit: :infinity
    broadcasted_process_id_structs_from_hub = message.plDeliver.message.procInitializeSystem.processes

    condition_lambda = fn x -> x.owner == state.owner and x.index == state.process_index end
    process_id_struct = broadcasted_process_id_structs_from_hub |> Enum.filter(fn x -> condition_lambda.(x) end) |> Enum.at(0)
    other_process_id_structs = broadcasted_process_id_structs_from_hub |> Enum.reject(fn x -> condition_lambda.(x) end)

    GenServer.cast(state.pl_memory_pid, {:save_process_id_structs, other_process_id_structs, process_id_struct})
    GenServer.cast(state.pl_memory_pid, {:save_system_id, message.systemId})
  end

end
