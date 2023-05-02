defmodule DistributedAlgorithmsApp.BestEffortBroadcastLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.NnAtomicRegisterLayer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  require Logger

  def receive_message(message, state) do
    deliver_message(message, state)
  end

  defp deliver_message(message, state) do
    update_message = %Proto.Message {
      type: :BEB_DELIVER,
      bebDeliver: %Proto.BebDeliver {sender: message.plDeliver.sender, message: message.plDeliver.message}
    }

    keys = [:plDeliver, :message, :ToAbstractionId]
    to_abstraction_id = get_in(message, Enum.map(keys, &Access.key!(&1)))

    cond do
      to_abstraction_id == "app" -> AppLayer.receive_message(update_message, state)
      Regex.match?(~r/app\.nnar\[[a-zA-Z]+[0-9]*\]/, to_abstraction_id) -> NnAtomicRegisterLayer.receive_message(update_message, state)
      true -> AppLayer.receive_message(update_message, state)
    end
  end

  def send_broadcast_message(message, process_id_struct, state) do
    Logger.info("BEST_EFFORT_BROADCAST_LAYER: SENDING BROADCAST WITH #{message.bebBroadcast.message.type}")
    keys = [:ToAbstractionId]
    to_abstraction_id = get_in(message, Enum.map(keys, &Access.key!(&1)))
    abstraction_id_with_cut_token =
      Regex.split(~r/\./, to_abstraction_id)
      |> Enum.drop(-1)
      |> Enum.join(".")

    actual_message = message.bebBroadcast.message
      |> update_in([Access.key!(:FromAbstractionId)], fn _ -> abstraction_id_with_cut_token end)
      |> update_in([Access.key!(:ToAbstractionId)], fn _ -> abstraction_id_with_cut_token end)

    updated_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: to_abstraction_id <> ".pl",
      ToAbstractionId: to_abstraction_id <> ".pl",
      plSend: %Proto.PlSend {
        destination: process_id_struct,
        message: actual_message
      }
    }

    PerfectLinkLayer.send_value_to_process(updated_message, state)
  end

  def read_register_values(message, state) do
    {:ok, to_abstraction_id} = Map.fetch(message, :ToAbstractionId)

    Enum.each(state.process_id_structs, fn x ->
      updated_message = %Proto.Message {
        type: :PL_SEND,
        FromAbstractionId: to_abstraction_id,
        ToAbstractionId: to_abstraction_id <> ".pl",
        plSend: %Proto.PlSend{
          destination: x,
          message: message.bebBroadcast.message
        }
      }
      PerfectLinkLayer.send_value_to_process(updated_message, state)
    end)
  end
end
