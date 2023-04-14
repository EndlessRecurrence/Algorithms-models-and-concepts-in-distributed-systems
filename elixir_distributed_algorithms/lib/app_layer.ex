defmodule DistributedAlgorithmsApp.AppLayer do
  alias Protobuf
  require Logger

  def receive_process_initialization_message_and_save_to_memory(pl_deliver_message, state) do
    IO.inspect pl_deliver_message, label: "APP_LAYER - PL_DELIVER_MESSAGE", limit: :infinity
    broadcasted_process_id_structs_from_hub = pl_deliver_message.plDeliver.processes

    filtered_process_structs =
      broadcasted_process_id_structs_from_hub
        |> Enum.filter(fn x ->
          x.owner == state.owner and x.index == state.process_index
        end)

    new_state =
      state
      |> Map.put(:process_id_struct, Enum.at(filtered_process_structs, 0))
      |> Map.put(:process_id_structs, broadcasted_process_id_structs_from_hub)

    GenServer.cast(state.pl_memory_pid, {:save_process_id_structs, new_state.process_id_structs, new_state.process_id_struct})
  end

end
