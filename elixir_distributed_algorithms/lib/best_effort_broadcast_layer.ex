defmodule DistributedAlgorithmsApp.BestEffortBroadcastLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.PerfectLinkHandler

  def receive_message(message, state) do
    deliver_message(message, state)
  end

  defp deliver_message(message, state) do
    update_message = %Proto.Message {
      type: :BEB_DELIVER,
      bebDeliver: %Proto.BebDeliver {sender: message.plDeliver.sender, message: message.plDeliver.message}
    }

    cond do
      Map.get(message, :ToAbstractionId) == nil -> AppLayer.receive_message(update_message, state)
      true -> AppLayer.receive_message(update_message, state)
    end
  end

  def send_broadcast_message(message, process_id_struct, state) do
    actual_message = message.bebBroadcast.message
      |> update_in([Access.key!(:FromAbstractionId)], fn _ -> "app" end)
      |> update_in([Access.key!(:ToAbstractionId)], fn _ -> "app" end)
    updated_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: "app.beb.pl",
      ToAbstractionId: "app.beb.pl",
      plSend: %Proto.PlSend {
        destination: process_id_struct,
        message: actual_message
      }
    }

    PerfectLinkHandler.send_broadcast_value_to_process(updated_message, state)
  end
end
